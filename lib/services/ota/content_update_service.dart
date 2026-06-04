/// OTA content update service (ADR 0017).
///
/// Orchestrates the VOLUNTARY "Check for updates" flow; only ever runs on the
/// parent's explicit tap (never on launch, never in the background).
///
///   check():  fetch manifest.json + manifest.json.sig -> verify the detached
///             signature against the trust-list -> parse -> check minAppVersion
///             -> compare contentVersion to what is applied. Returns what (if
///             anything) is available; applies nothing.
///   apply():  download each file -> verify sha256 -> atomically apply via the
///             overlay store. A hash mismatch ABORTS without applying, so the
///             prior overlay stays active (review-and-apply, ADR 0017).
///
/// The manifest describes the OVERLAY (the small set of corrected files that
/// differ from the bundled app), NOT the full content catalog, so a check is a
/// few KB and an apply downloads only the corrections.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'content_http_client.dart';
import 'content_manifest.dart';
import 'content_overlay_store.dart';
import 'manifest_signature_verifier.dart';

enum UpdateStatus {
  /// The applied content version already matches the server.
  upToDate,

  /// A newer, verified content version is available (see [UpdateCheck.manifest]).
  available,

  /// The server's content requires a newer app than this build.
  incompatible,

  /// No content base URL configured (OTA deploy deferred): a clean no-op.
  notConfigured,

  /// Fetch / signature / parse failure. Nothing was applied.
  error,
}

class UpdateCheck {
  const UpdateCheck(this.status, {this.manifest, this.message});

  final UpdateStatus status;

  /// The verified manifest, present when [status] is [UpdateStatus.available]
  /// (and [UpdateStatus.upToDate]); pass it to [ContentUpdateService.apply].
  final ContentManifest? manifest;

  /// Human-readable detail when [status] is [UpdateStatus.error].
  final String? message;
}

class ContentUpdateService {
  ContentUpdateService({
    required this.baseUrl,
    required this.appVersion,
    required ContentHttpClient httpClient,
    required ContentOverlayStore store,
    required ManifestSignatureVerifier verifier,
    this.appBuild = '',
  })  : _http = httpClient,
        _store = store,
        _verifier = verifier;

  /// The content root, e.g. `https://.../content`. Null/empty means OTA is not
  /// configured yet (deploy deferred), so [check] is a clean no-op.
  final String? baseUrl;

  /// The marketing version (e.g. `0.1.0`), used for the [minAppVersion]
  /// compatibility check. This is the ONLY app data sent on the wire
  /// (`X-Lighthouse-App-Version`); keep it the marketing version, never the
  /// combined identity (ADR 0021, HIGH-1).
  final String appVersion;

  /// The build number (e.g. `8`), used ONLY locally to form the combined
  /// `"<version>+<build>"` release identity for the ADR 0021 targetVersion gate.
  /// It is never sent on the wire. Empty (the default) means "unknown build",
  /// which compares as build `0`.
  final String appBuild;

  final ContentHttpClient _http;
  final ContentOverlayStore _store;
  final ManifestSignatureVerifier _verifier;

  static const String _manifestName = 'manifest.json';
  static const String _signatureName = 'manifest.json.sig';

  String get _root {
    final b = baseUrl!;
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  Future<UpdateCheck> check() async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      return const UpdateCheck(UpdateStatus.notConfigured);
    }
    try {
      final manifestBytes = await _http.getBytes('$_root/$_manifestName');
      final signatureBytes = await _http.getBytes('$_root/$_signatureName');
      final verified = await _verifier.verify(
        manifestBytes: manifestBytes,
        signatureBytes: signatureBytes,
      );
      if (!verified) {
        return const UpdateCheck(UpdateStatus.error,
            message: 'manifest signature verification failed');
      }
      final manifest = ContentManifest.parse(utf8.decode(manifestBytes));
      if (!_isCompatible(manifest.minAppVersion)) {
        return UpdateCheck(UpdateStatus.incompatible, manifest: manifest);
      }
      final applied = await _store.readState();
      // Monotonic guard (ADR 0017): never offer a manifest that is not strictly
      // newer than what is applied. Equal = already up to date; lower = a
      // downgrade/rollback attempt (a replayed, validly-signed OLD manifest),
      // which we refuse even though its signature is valid.
      final newerThanApplied = manifest.sequence > applied.sequence;
      // Release-version gate (ADR 0021): if this manifest's corrections have
      // already been folded into the bundle at or before this build's release,
      // do not re-offer them. Compared purely locally; targetVersion == null
      // means no fold has shipped yet, so it stays eligible. This can only ever
      // SUPPRESS an offer, never enable one the sequence guard would refuse.
      final bundleAlreadyHasIt = manifest.targetVersion != null &&
          compareAppVersion(_deviceIdentity, manifest.targetVersion!) >= 0;
      return UpdateCheck(
        newerThanApplied && !bundleAlreadyHasIt
            ? UpdateStatus.available
            : UpdateStatus.upToDate,
        manifest: manifest,
      );
    } on ContentHttpException catch (e) {
      return UpdateCheck(UpdateStatus.error, message: e.message);
    } on ContentManifestException catch (e) {
      return UpdateCheck(UpdateStatus.error, message: e.message);
    } catch (e) {
      return UpdateCheck(UpdateStatus.error, message: '$e');
    }
  }

  /// Downloads + sha256-verifies every file in [manifest], then atomically
  /// applies the set. Throws on a hash mismatch or download error WITHOUT
  /// applying (the prior overlay stays active).
  Future<void> apply(ContentManifest manifest) async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      throw const ContentManifestException('OTA not configured');
    }
    // Re-assert the monotonic guard at apply time (defense in depth): never
    // apply a manifest that is not strictly newer than what is applied.
    final applied = await _store.readState();
    if (manifest.sequence <= applied.sequence) {
      throw ContentManifestException(
        'refusing to apply non-newer manifest '
        '(sequence ${manifest.sequence} <= applied ${applied.sequence})',
      );
    }
    final files = <String, List<int>>{};
    for (final entry in manifest.files) {
      // Bound the download at the manifest-declared size (sha256 then verifies
      // the exact content); a server returning more than declared is rejected
      // before it can buffer (review M4).
      final bytes =
          await _http.getBytes('$_root/${entry.path}', maxBytes: entry.bytes);
      final actual = sha256.convert(bytes).toString();
      if (actual != entry.sha256) {
        throw ContentManifestException(
          'sha256 mismatch for ${entry.path}: '
          'expected ${entry.sha256}, got $actual',
        );
      }
      files[entry.path] = bytes;
    }
    await _store.apply(
      contentVersion: manifest.contentVersion,
      sequence: manifest.sequence,
      files: files,
    );
  }

  bool _isCompatible(String? minAppVersion) {
    if (minAppVersion == null || minAppVersion.isEmpty) return true;
    return _compareVersions(appVersion, minAppVersion) >= 0;
  }

  /// This build's combined release identity, `"<version>+<build>"`, used ONLY
  /// for the local [ContentManifest.targetVersion] gate. Never sent on the wire.
  String get _deviceIdentity => '$appVersion+$appBuild';
}

/// Compares two combined `"<version>+<build>"` release identities (ADR 0021).
/// Returns >0 if [a] is a later release than [b], 0 if equal, <0 if earlier.
///
/// The marketing version (before the first `+`) is compared first with
/// [_compareVersions]; the build number (after the first `+`) breaks ties as an
/// integer via `int.tryParse(...) ?? 0`, so a missing, empty, or non-numeric
/// build collapses cleanly to 0 (`"0.1.0" == "0.1.0+0" == "0.1.0+"`). Comparing
/// the marketing version FIRST makes this robust to an iOS build-number reset on
/// a marketing bump (e.g. `0.2.0+1` correctly outranks `0.1.0+8`).
int compareAppVersion(String a, String b) {
  final (av, ab) = _splitVersionBuild(a);
  final (bv, bb) = _splitVersionBuild(b);
  final byVersion = _compareVersions(av, bv);
  if (byVersion != 0) return byVersion;
  return ab - bb;
}

/// Splits `"0.1.0+8"` into `("0.1.0", 8)`. No `+` -> build 0; empty or
/// non-numeric build -> 0.
(String, int) _splitVersionBuild(String s) {
  final plus = s.indexOf('+');
  if (plus < 0) return (s, 0);
  final version = s.substring(0, plus);
  final build = int.tryParse(s.substring(plus + 1)) ?? 0;
  return (version, build);
}

/// Compares dotted numeric versions: >0 if [a] > [b], 0 if equal, <0 if [a] < [b].
/// Missing segments are treated as 0; a segment's leading integer is used, so a
/// pre-release/build suffix ("1.2.3-rc1") orders by its numeric part ("3")
/// rather than collapsing to 0.
int _compareVersions(String a, String b) {
  final pa = a.split('.');
  final pb = b.split('.');
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final ai = i < pa.length ? _segmentValue(pa[i]) : 0;
    final bi = i < pb.length ? _segmentValue(pb[i]) : 0;
    if (ai != bi) return ai - bi;
  }
  return 0;
}

/// Leading non-negative integer of a version segment, or 0 if it has none.
/// `"3-rc1"` -> 3, `"rc1"` -> 0, `"12"` -> 12.
int _segmentValue(String segment) {
  final match = RegExp(r'^\d+').firstMatch(segment);
  return match == null ? 0 : int.parse(match.group(0)!);
}
