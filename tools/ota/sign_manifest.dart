/// OTA manifest signer (ADR 0017).
///
/// Reads the EXACT bytes of a built manifest.json, signs them with the offline
/// Ed25519 private seed, and writes the detached signature as manifest.json.sig
/// next to it. The device verifies this signature against its bundled trust-list
/// before trusting anything in the manifest, so what is signed here MUST be the
/// byte-for-byte file that gets uploaded (do not re-serialize between signing
/// and upload).
///
///   dart run tools/ota/sign_manifest.dart \
///     --manifest ./ota-content/manifest.json \
///     --key ~/khf-keys/ota-signing.key \
///     [--public-key <base64>]   # optional self-check before writing
///
/// The signer self-verifies its own signature before writing the .sig. If
/// --public-key is given (the value in kOtaTrustedPublicKeys), it also asserts
/// the signature verifies under THAT key, catching a wrong-seed mistake before
/// it ships content the installed app would reject.
library;

import 'dart:convert';
import 'dart:io';

// Import the verifier directly, NOT the ota.dart barrel: the barrel pulls in
// content_overlay_store -> path_provider -> dart:ui, which a plain `dart run`
// (no Flutter engine) cannot load.
import 'package:lighthouse/services/ota/manifest_signature_verifier.dart';

import 'ota_signing.dart';

Future<int> main(List<String> args) async {
  final manifestPath = _argValue(args, '--manifest');
  final keyPath = _argValue(args, '--key');
  final publicKeyB64 = _argValue(args, '--public-key');

  if (manifestPath == null || keyPath == null) {
    stderr.writeln('usage: dart run tools/ota/sign_manifest.dart '
        '--manifest <manifest.json> --key <private-seed-file> '
        '[--public-key <base64>]');
    return 64;
  }

  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('manifest not found: $manifestPath');
    return 66;
  }
  final keyFile = File(keyPath);
  if (!keyFile.existsSync()) {
    stderr.writeln('private key file not found: $keyPath');
    return 66;
  }

  // Sign the exact on-disk bytes (NOT a re-encode), since those are what ships.
  final manifestBytes = manifestFile.readAsBytesSync();
  final List<int> seed;
  try {
    seed = base64.decode(keyFile.readAsStringSync().trim());
  } catch (_) {
    stderr.writeln('private key file is not valid base64');
    return 65;
  }

  final List<int> signature;
  try {
    signature = await signManifestBytes(seed, manifestBytes);
  } on ArgumentError catch (e) {
    stderr.writeln(e.message);
    return 65;
  }

  // Self-check against the optional public key (the trust-list value). This is
  // the same verifier the device runs, so a pass here means the device accepts it.
  if (publicKeyB64 != null) {
    final ok = await ManifestSignatureVerifier(
      trustedPublicKeysBase64: [publicKeyB64],
    ).verify(manifestBytes: manifestBytes, signatureBytes: signature);
    if (!ok) {
      stderr.writeln('self-check FAILED: this signature does not verify under '
          'the given --public-key. Wrong key pair? Not writing the .sig.');
      return 1;
    }
    stdout.writeln('Self-check passed against the provided public key.');
  }

  final sigPath = '$manifestPath.sig';
  File(sigPath).writeAsBytesSync(signature, flush: true);
  stdout.writeln('Wrote $sigPath (${signature.length}-byte detached signature)');
  stdout.writeln('Upload manifest.json and manifest.json.sig together.');
  return 0;
}

String? _argValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}
