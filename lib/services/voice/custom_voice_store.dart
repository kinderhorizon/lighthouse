/// Persistence for parent-recorded custom voice clips (ADR 0019).
///
/// Stores a mapping `buttonId -> audio filename` as a single JSON file, and the
/// recorded clips themselves in a sibling `custom_voices/` directory, both under
/// the app support directory (the SAME backup-excluded location as custom
/// buttons / favourites / layout, ADR 0002 / 0012 / 0013 / 0014).
///
/// PRIVACY (disclosed on kinderhorizon.org/lighthouse/privacy): a recording is
/// kept ONLY on the device. It is never transmitted, never attached to a crash
/// report or feedback payload, and is reachable only behind the parental math
/// gate. The device's own backup (iCloud / Google) may include it; that copy is
/// the parent's, not ours.
///
/// A corrupt file or a missing clip loads as "no custom voice", so the tile
/// simply falls back to the built-in voice: a bad clip must never silence a
/// non-speaking child (ADR 0004).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../util/atomic_file.dart';

/// Thrown by [CustomVoiceStore.importClip] when a recording is unexpectedly
/// large or not a recognized audio type (defence in depth; the recorder only
/// ever writes a short AAC clip).
class CustomVoiceException implements Exception {
  const CustomVoiceException(this.message);
  final String message;
  @override
  String toString() => 'CustomVoiceException: $message';
}

class CustomVoiceStore {
  CustomVoiceStore({Directory? dirOverride}) : _dirOverride = dirOverride;

  final Directory? _dirOverride;

  static const String fileName = 'custom_voices.json';
  static const String clipsSubdir = 'custom_voices';

  /// Upper bound on a recorded clip. A custom voice is a single word or short
  /// phrase; this rejects a runaway recording before it is copied into storage.
  static const int maxClipBytes = 5 * 1024 * 1024;

  /// Recognized recorded-audio extensions (lowercased).
  static const Set<String> allowedClipExtensions = {
    '.m4a', '.aac', '.mp4', '.wav', '.caf',
  };

  Directory? _resolvedBase;

  Future<Directory> _base() async {
    if (_resolvedBase != null) return _resolvedBase!;
    final base = _dirOverride ?? await getApplicationSupportDirectory();
    if (!base.existsSync()) await base.create(recursive: true);
    _resolvedBase = base;
    return base;
  }

  Future<File> _file() async => File('${(await _base()).path}/$fileName');

  String _clipsDirPath(Directory base) => '${base.path}/$clipsSubdir';

  /// Reads the raw `buttonId -> filename` map (filenames as stored, relative).
  /// Empty on first run or any corruption.
  Future<Map<String, String>> _readRaw() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return {};
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return {};
      return {
        for (final e in raw.entries)
          if (e.value is String && (e.value as String).isNotEmpty)
            e.key.toString(): e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  /// Loads the map with ABSOLUTE clip paths, resolved against the live clips
  /// directory so the path survives a delete-reinstall or device restore (the
  /// iOS app-container UUID in an absolute path does not).
  Future<Map<String, String>> load() async {
    final raw = await _readRaw();
    final dir = _clipsDirPath(await _base());
    return {
      for (final e in raw.entries) e.key: '$dir/${e.value}',
    };
  }

  Future<void> _write(Map<String, String> relative) async {
    final f = await _file();
    await writeStringAtomically(f, jsonEncode(relative));
  }

  /// Copies [source] (a freshly recorded temp clip) into the clips directory,
  /// named by the button id, persists the mapping, and returns the updated map
  /// with absolute paths. Replaces any prior clip for [buttonId].
  Future<Map<String, String>> importClip(
    File source, {
    required String buttonId,
  }) async {
    // [buttonId] is interpolated into a filesystem path; reject anything that is
    // not a bare slug (no separators, no traversal), mirroring CustomButtonStore.
    if (buttonId.isEmpty ||
        buttonId.contains('/') ||
        buttonId.contains(r'\') ||
        buttonId.contains('..')) {
      throw CustomVoiceException('unsafe button id: "$buttonId"');
    }
    final ext = _extensionOf(source.path).toLowerCase();
    if (!allowedClipExtensions.contains(ext)) {
      throw CustomVoiceException('unsupported audio type: $ext');
    }
    final length = await source.length();
    if (length > maxClipBytes) {
      throw CustomVoiceException(
          'clip too large ($length bytes, max $maxClipBytes)');
    }
    final base = await _base();
    final dir = Directory(_clipsDirPath(base));
    if (!dir.existsSync()) await dir.create(recursive: true);

    final raw = await _readRaw();
    // Delete a prior clip for this id (it may have a different extension).
    final prior = raw[buttonId];
    // Only resolve a stored filename for deletion if it is a bare basename; a
    // locally-tampered entry with a separator or `..` is ignored (bounds an
    // arbitrary-delete to this store's own directory).
    if (prior != null && _isSafeStoredName(prior)) {
      await _deleteFileQuietly(File('${dir.path}/$prior'));
    }
    final name = '$buttonId$ext';
    await source.copy('${dir.path}/$name');
    final next = {...raw, buttonId: name};
    await _write(next);
    return load();
  }

  /// Removes the custom voice for [buttonId] (deleting its file) and returns the
  /// updated map with absolute paths. Restores the built-in voice for the tile.
  Future<Map<String, String>> remove(String buttonId) async {
    final raw = await _readRaw();
    final name = raw[buttonId];
    if (name == null) return load();
    if (_isSafeStoredName(name)) {
      await _deleteFileQuietly(File('${_clipsDirPath(await _base())}/$name'));
    }
    final next = {...raw}..remove(buttonId);
    await _write(next);
    return load();
  }

  /// Removes the custom voice for each id in [buttonIds] (deleting their files)
  /// and returns the updated map. Used by the editor's "reset this board" for
  /// the ids currently on that board. A no-op for ids without a clip.
  Future<Map<String, String>> removeMany(Iterable<String> buttonIds) async {
    final raw = await _readRaw();
    final targets = buttonIds.toSet();
    if (!raw.keys.any(targets.contains)) return load();
    final dir = _clipsDirPath(await _base());
    for (final entry in raw.entries) {
      if (targets.contains(entry.key) && _isSafeStoredName(entry.value)) {
        await _deleteFileQuietly(File('$dir/${entry.value}'));
      }
    }
    final next = {
      for (final e in raw.entries)
        if (!targets.contains(e.key)) e.key: e.value,
    };
    await _write(next);
    return load();
  }

  /// Removes EVERY custom voice across all tiles (deleting the clips). Used by
  /// the editor's "reset everything".
  Future<Map<String, String>> clearAll() async {
    final dir = Directory(_clipsDirPath(await _base()));
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {/* best-effort */}
    }
    await _write(<String, String>{});
    return load();
  }

  /// A stored filename read back from JSON must be a bare basename: non-empty,
  /// no path separators, no `..`, no NUL. Bounds a local-tamper arbitrary-path
  /// resolution to this store's own clips directory.
  static bool _isSafeStoredName(String name) =>
      name.isNotEmpty &&
      !name.contains('/') &&
      !name.contains('\\') &&
      !name.contains('..') &&
      !name.contains('\u0000');

  static Future<void> _deleteFileQuietly(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // Best-effort: a leftover clip is harmless, the mapping is the source of
      // truth and was rewritten without it.
    }
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.bin';
    final ext = path.substring(dot);
    return ext.contains('/') ? '.bin' : ext;
  }
}
