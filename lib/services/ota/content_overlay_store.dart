/// OTA content overlay store (ADR 0017).
///
/// Owns the on-device directory of OTA-applied content corrections and answers
/// "is there an overlaid version of this content path?". This is the NEW
/// precedence layer: an OTA file for a given path WINS over the bundled asset
/// (the opposite of BoardRegistry's bundled-first import precedence, and a
/// different mechanism from ADR 0015's fresh-id imports).
///
/// Apply is ATOMIC via a pointer swap: the files for a content version are
/// written under `<overlay>/v/<sequence>/...`, then `pointer.json` is updated to
/// point at that version LAST. A crash mid-write leaves the previous pointer
/// (and previous version dir) intact, so a non-speaking child's board is never
/// half-updated. The previous version is kept until a new one commits
/// (last-known-good for rollback). The version dir is keyed on the manifest
/// `sequence` (unique + strictly monotonic), NOT the contentVersion string:
/// keying on contentVersion let a newer manifest that reused a prior version
/// string delete the currently-active dir during the write window.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../util/atomic_file.dart';
import 'content_manifest.dart';

/// What is currently applied: the active content version and the set of content
/// paths it provides. [isEmpty] means nothing is applied (everything resolves
/// to the bundled asset).
class OverlayState {
  const OverlayState({
    required this.activeVersion,
    required this.sequence,
    required this.files,
  });

  const OverlayState.empty()
      : activeVersion = null,
        sequence = 0,
        files = const {};

  final String? activeVersion;

  /// The applied manifest's monotonic sequence (0 when nothing is applied).
  /// The update service refuses to apply a manifest with sequence <= this.
  final int sequence;

  final Set<String> files;

  bool get isEmpty => activeVersion == null;
}

class ContentOverlayStore {
  ContentOverlayStore({Directory? dirOverride}) : _dirOverride = dirOverride;

  final Directory? _dirOverride;

  /// Subdirectory (under app support) holding applied OTA content. Public so
  /// the backup-exclusion guard (test/privacy/backup_exclusion_test.dart) can
  /// bind to it: overlaid boards/clips/pictograms are corrected content that
  /// must not sync to cloud backup, same posture as the rest of app data.
  static const String subdirName = 'content_overlay';
  static const String _subdir = subdirName;
  static const String _pointerName = 'pointer.json';
  static const String _versionsSubdir = 'v';

  Directory? _resolvedRoot;

  Future<Directory> _root() async {
    if (_resolvedRoot != null) return _resolvedRoot!;
    final base = _dirOverride ?? await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_subdir');
    if (!dir.existsSync()) await dir.create(recursive: true);
    _resolvedRoot = dir;
    return dir;
  }

  Future<File> _pointerFile() async =>
      File('${(await _root()).path}/$_pointerName');

  /// Directory holding one applied version's files, named by the manifest
  /// [sequence]. sequence is unique and strictly monotonic (the update-service
  /// gate refuses sequence <= the active one), so two applies never collide on
  /// the same dir, and an int can never contain a path separator or `..`.
  Future<Directory> _versionDir(int sequence) async =>
      Directory('${(await _root()).path}/$_versionsSubdir/$sequence');

  /// Reads the current applied state. A missing or unparseable pointer is
  /// treated as "nothing applied" (fail safe to bundled), never an error.
  Future<OverlayState> readState() async {
    try {
      final pointer = await _pointerFile();
      if (!pointer.existsSync()) return const OverlayState.empty();
      final decoded = jsonDecode(await pointer.readAsString());
      if (decoded is! Map<String, dynamic>) return const OverlayState.empty();
      final version = decoded['activeVersion'];
      final filesRaw = decoded['files'];
      if (version is! String || version.isEmpty || filesRaw is! List) {
        return const OverlayState.empty();
      }
      final seq = decoded['sequence'];
      return OverlayState(
        activeVersion: version,
        sequence: seq is int && seq >= 0 ? seq : 0,
        files: {
          for (final f in filesRaw)
            if (f is String) f,
        },
      );
    } catch (_) {
      return const OverlayState.empty();
    }
  }

  /// Returns the overlaid [File] for [contentPath] if the active version
  /// provides it and the file exists on disk, else null (caller falls back to
  /// the bundled asset). Unsafe paths always resolve to null.
  Future<File?> overlayFileFor(String contentPath) async {
    if (!ContentManifestEntry.isSafeRelativePath(contentPath)) return null;
    final state = await readState();
    if (state.isEmpty || !state.files.contains(contentPath)) return null;
    final file =
        File('${(await _versionDir(state.sequence)).path}/$contentPath');
    return file.existsSync() ? file : null;
  }

  /// Atomically applies [files] (contentPath -> bytes) as [contentVersion].
  /// Writes all files under the new version dir first, then flips the pointer
  /// LAST (the atomic commit), then garbage-collects older version dirs. Throws
  /// only if the new version cannot be fully written (in which case the pointer
  /// is untouched and the prior version stays active).
  Future<void> apply({
    required String contentVersion,
    required int sequence,
    required Map<String, List<int>> files,
  }) async {
    // contentVersion is still validated (it is stored in the pointer) and the
    // sequence is range-checked, so a direct caller cannot escape the versions
    // dir. The dir itself is keyed on sequence, not contentVersion (see
    // _versionDir): defense in depth, like the per-path check below and the
    // sequence re-guard in ContentUpdateService.apply.
    if (!ContentManifest.isSafeVersionSegment(contentVersion)) {
      throw ContentManifestException(
          'unsafe contentVersion on apply: $contentVersion');
    }
    if (sequence <= 0) {
      throw ContentManifestException(
          'sequence must be positive on apply: $sequence');
    }
    for (final path in files.keys) {
      if (!ContentManifestEntry.isSafeRelativePath(path)) {
        throw ContentManifestException('unsafe content path on apply: $path');
      }
    }
    final versionDir = await _versionDir(sequence);
    // Start clean if a partial dir for this version exists from a prior failure.
    if (versionDir.existsSync()) await versionDir.delete(recursive: true);
    await versionDir.create(recursive: true);
    for (final entry in files.entries) {
      final dest = File('${versionDir.path}/${entry.key}');
      if (!dest.parent.existsSync()) {
        await dest.parent.create(recursive: true);
      }
      await dest.writeAsBytes(entry.value, flush: true);
    }
    // Capture the currently-applied state as the rollback target (last-known-
    // good) BEFORE flipping the pointer.
    final prior = await readState();
    // Atomic commit: the pointer only names this version after every file is on
    // disk, so a crash before here leaves the old version active.
    final pointer = await _pointerFile();
    await writeStringAtomically(
      pointer,
      jsonEncode({
        'activeVersion': contentVersion,
        'sequence': sequence,
        'files': files.keys.toList(),
        if (!prior.isEmpty)
          'previous': {
            'activeVersion': prior.activeVersion,
            'sequence': prior.sequence,
            'files': prior.files.toList(),
          },
      }),
    );
    // Retain the new version AND the immediately-prior one (rollback target);
    // GC anything older. Dirs are named by sequence, so the keep-set is too.
    await _gcVersionsExcept({
      '$sequence',
      if (!prior.isEmpty) '${prior.sequence}',
    });
  }

  /// Reverts to the immediately-prior applied version (last-known-good), if one
  /// exists and its files are still on disk. Returns true if a rollback
  /// happened. Single-level: after rolling back there is no further previous.
  /// Lets a parent undo a bad-but-valid correction on-device without nuking
  /// every correction (which is what [clear] does). Note: a later "Check for
  /// updates" may re-offer the rolled-back version, since the published manifest
  /// still carries its higher sequence; the durable fix is a new published
  /// correction.
  Future<bool> rollback() async {
    final pointer = await _pointerFile();
    if (!pointer.existsSync()) return false;
    try {
      final decoded = jsonDecode(await pointer.readAsString());
      if (decoded is! Map<String, dynamic>) return false;
      final prev = decoded['previous'];
      if (prev is! Map<String, dynamic>) return false;
      final pv = prev['activeVersion'];
      final pf = prev['files'];
      final ps = prev['sequence'];
      // The prior dir is located by its sequence, so a valid positive sequence
      // is required to roll back (not just the version string).
      if (pv is! String || pv.isEmpty || pf is! List) return false;
      if (ps is! int || ps <= 0) return false;
      if (!(await _versionDir(ps)).existsSync()) return false;
      await writeStringAtomically(
        pointer,
        jsonEncode({
          'activeVersion': pv,
          'sequence': ps,
          'files': [
            for (final f in pf)
              if (f is String) f,
          ],
        }),
      );
      await _gcVersionsExcept({'$ps'});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes all applied content (reverts every path to the bundled asset).
  Future<void> clear() async {
    final pointer = await _pointerFile();
    if (pointer.existsSync()) await pointer.delete();
    final versions = Directory('${(await _root()).path}/$_versionsSubdir');
    if (versions.existsSync()) await versions.delete(recursive: true);
  }

  Future<void> _gcVersionsExcept(Set<String> keep) async {
    final versions = Directory('${(await _root()).path}/$_versionsSubdir');
    if (!versions.existsSync()) return;
    for (final entity in versions.listSync()) {
      if (entity is Directory && !keep.contains(entity.path.split('/').last)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          // Best-effort GC; a leftover old version dir is harmless (the pointer
          // decides what is active).
        }
      }
    }
  }
}
