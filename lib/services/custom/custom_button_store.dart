/// Persistence for parent-authored custom buttons (ADR 0012 / ADR 0014).
///
/// Stores the button list as a single JSON file and copies picked images into
/// a sibling directory, both under the app support directory (excluded from OS
/// backup per ADR 0002). Deliberately NOT an Isar collection, to avoid a schema
/// version bump (ADR 0005); this mirrors the imported-boards file pattern.
///
/// ADR 0014 changes the on-disk shape from a bare array of buttons to an object
/// `{"buttons": [...], "counters": {boardId: nextN}}`. `counters` is a per-board
/// monotonic HIGH-WATER MARK: [allocateId] reads it, hands out
/// `custom_<boardId>_<n>`, and persists `n + 1` immediately. It is never
/// recomputed from the live buttons, so deleting the highest-numbered custom
/// button and then adding another cannot reuse its id (which would silently
/// inherit the deleted button's bandit posteriors, never purged on delete).
/// A legacy bare-array file still loads (its buttons migrate to derived ids via
/// [CustomButton.fromJson]); it is rewritten in the new shape on the next save.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';
import '../util/atomic_file.dart';

/// Thrown by [CustomButtonStore.importImage] when a picked image is too large
/// or not a recognized image type. The UI catches it and tells the parent,
/// rather than silently copying a 50 MP photo into app storage.
class CustomButtonImageException implements Exception {
  const CustomButtonImageException(this.message);
  final String message;
  @override
  String toString() => 'CustomButtonImageException: $message';
}

class CustomButtonStore {
  CustomButtonStore({Directory? dirOverride}) : _dirOverride = dirOverride;

  final Directory? _dirOverride;

  static const String fileName = 'custom_buttons.json';
  static const String imagesSubdir = 'custom_images';

  /// Upper bound on a picked custom-button image. A button icon is small; this
  /// rejects an oversized photo before it is copied into app storage (bloat,
  /// slow decode, slow launch). Metadata-stripping / transcoding to a bounded
  /// format is a future hardening; the size + type guard is the floor.
  static const int maxImageBytes = 8 * 1024 * 1024;

  /// Recognized image extensions for a picked custom-button image (lowercased).
  static const Set<String> allowedImageExtensions = {
    '.png', '.jpg', '.jpeg', '.webp', '.gif', '.heic', '.heif', '.bmp',
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

  /// Reads the raw persisted state: buttons (with RELATIVE image paths, as
  /// stored) plus the per-board id counters. Tolerates both the new object
  /// shape and the legacy bare array. Returns empty state on first run or any
  /// corruption (a bad file must never block the board).
  Future<({List<CustomButton> buttons, Map<String, int> counters})>
      _readRaw() async {
    try {
      final f = await _file();
      if (!f.existsSync()) {
        return (buttons: <CustomButton>[], counters: <String, int>{});
      }
      final raw = jsonDecode(await f.readAsString());
      final List<dynamic> listPart;
      final counters = <String, int>{};
      if (raw is List) {
        listPart = raw; // legacy bare-array file
      } else if (raw is Map) {
        listPart = raw['buttons'] is List ? raw['buttons'] as List : const [];
        final c = raw['counters'];
        if (c is Map) {
          for (final e in c.entries) {
            if (e.key is String && e.value is int) {
              counters[e.key as String] = e.value as int;
            }
          }
        }
      } else {
        return (buttons: <CustomButton>[], counters: <String, int>{});
      }
      final buttons = <CustomButton>[
        for (final e in listPart)
          if (e is Map<String, dynamic>) CustomButton.fromJson(e),
      ];
      return (buttons: buttons, counters: counters);
    } catch (_) {
      return (buttons: <CustomButton>[], counters: <String, int>{});
    }
  }

  /// Loads all persisted custom buttons with ABSOLUTE image paths.
  ///
  /// Image paths are stored RELATIVE (filename only) and resolved against the
  /// live support directory here, so they survive a delete-reinstall or device
  /// restore (the iOS app-container UUID in an absolute path does not). The
  /// in-memory `imagePath` is therefore always absolute for the tile to render.
  Future<List<CustomButton>> load() async {
    final raw = await _readRaw();
    final imagesDirPath = '${(await _base()).path}/$imagesSubdir';
    return [
      for (final b in raw.buttons) _withAbsoluteImage(b, imagesDirPath),
    ];
  }

  Future<void> _write(
    List<CustomButton> buttons,
    Map<String, int> counters,
  ) async {
    final f = await _file();
    // Persist images as bare filenames, never the absolute container path.
    // Atomic write so an interrupted save cannot truncate the parent's buttons.
    await writeStringAtomically(
        f,
        jsonEncode({
          'buttons': [for (final b in buttons) _withRelativeImage(b).toJson()],
          'counters': counters,
        }));
  }

  /// Reserves and returns the next stable id for [boardId]
  /// (`custom_<boardId>_<n>`), persisting the incremented high-water mark
  /// immediately so the id is never reused even if the caller then fails to add
  /// the button. See the class doc for why this must not be recomputed.
  Future<String> allocateId(String boardId) async {
    final raw = await _readRaw();
    final n = raw.counters[boardId] ?? 0;
    await _write(raw.buttons, {...raw.counters, boardId: n + 1});
    return 'custom_${boardId}_$n';
  }

  static CustomButton _withRelativeImage(CustomButton b) {
    if (b.imagePath.isEmpty) return b;
    final slash = b.imagePath.lastIndexOf('/');
    final name = slash < 0 ? b.imagePath : b.imagePath.substring(slash + 1);
    return _copyWithImage(b, name);
  }

  static CustomButton _withAbsoluteImage(CustomButton b, String imagesDirPath) {
    if (b.imagePath.isEmpty || b.imagePath.startsWith('/')) return b;
    // The stored value must be a bare basename. A tampered relative entry with a
    // separator or `..` could otherwise escape the images dir when resolved,
    // including for deletion (arbitrary-delete within the sandbox). Drop the
    // reference rather than resolve it; the button just renders iconless.
    if (!isSafeStoredName(b.imagePath)) return _copyWithImage(b, '');
    return _copyWithImage(b, '$imagesDirPath/${b.imagePath}');
  }

  /// A stored filename read back from JSON must be a bare basename: non-empty,
  /// no path separators, no `..`, no NUL. Bounds a local-tamper arbitrary-path
  /// resolution to the store's own directory.
  static bool isSafeStoredName(String name) =>
      name.isNotEmpty &&
      !name.contains('/') &&
      !name.contains('\\') &&
      !name.contains('..') &&
      !name.contains('\u0000');

  static CustomButton _copyWithImage(CustomButton b, String imagePath) =>
      CustomButton(
        id: b.id,
        boardId: b.boardId,
        row: b.row,
        col: b.col,
        label: b.label,
        voiceOut: b.voiceOut,
        imagePath: imagePath,
      );

  /// Adds (or replaces, by stable [CustomButton.id]) [button] and returns the
  /// updated list with absolute image paths.
  Future<List<CustomButton>> add(CustomButton button) async {
    final raw = await _readRaw();
    final next = [
      for (final b in raw.buttons)
        if (b.id != button.id) b,
      button,
    ];
    await _write(next, raw.counters);
    return load();
  }

  /// Removes the button with [id] (deleting its image file too) and returns the
  /// updated list with absolute image paths.
  Future<List<CustomButton>> removeById(String id) async {
    final raw = await _readRaw();
    final imagesDirPath = '${(await _base()).path}/$imagesSubdir';
    for (final b in raw.buttons.where((b) => b.id == id)) {
      final abs = _withAbsoluteImage(b, imagesDirPath);
      if (abs.imagePath.isNotEmpty) {
        try {
          final img = File(abs.imagePath);
          if (img.existsSync()) await img.delete();
        } catch (_) {/* best-effort */}
      }
    }
    final next = raw.buttons.where((b) => b.id != id).toList();
    await _write(next, raw.counters);
    return load();
  }

  /// Removes EVERY custom button on [boardId] (deleting their images) and
  /// returns the updated list. The per-board id COUNTER is deliberately kept
  /// (never reset), so a future custom button can never reuse a removed id and
  /// inherit its bandit posteriors (see the class doc). Used by the editor's
  /// "reset this board".
  Future<List<CustomButton>> removeForBoard(String boardId) async {
    final raw = await _readRaw();
    final imagesDirPath = '${(await _base()).path}/$imagesSubdir';
    for (final b in raw.buttons.where((b) => b.boardId == boardId)) {
      await _deleteImageQuietly(_withAbsoluteImage(b, imagesDirPath));
    }
    final next = raw.buttons.where((b) => b.boardId != boardId).toList();
    await _write(next, raw.counters);
    return load();
  }

  /// Removes ALL custom buttons across every board (deleting their images),
  /// keeping the id counters (see [removeForBoard]). Used by the editor's
  /// "reset everything".
  Future<List<CustomButton>> clearAll() async {
    final raw = await _readRaw();
    final imagesDirPath = '${(await _base()).path}/$imagesSubdir';
    for (final b in raw.buttons) {
      await _deleteImageQuietly(_withAbsoluteImage(b, imagesDirPath));
    }
    await _write(const <CustomButton>[], raw.counters);
    return load();
  }

  static Future<void> _deleteImageQuietly(CustomButton abs) async {
    if (abs.imagePath.isEmpty) return;
    try {
      final img = File(abs.imagePath);
      if (img.existsSync()) await img.delete();
    } catch (_) {/* best-effort */}
  }

  /// Copies [source] into the persistent images directory and returns the new
  /// absolute path. The parent's original photo is left untouched.
  Future<String> importImage(File source, {required String suggestedName}) async {
    // [suggestedName] is interpolated into a filesystem path below, so the
    // store must not trust its caller for it (today the sole caller passes a
    // validated `custom_<boardId>_<n>` id, but a future one could pass a raw
    // filename). Reject anything that is not a bare slug: no separators, no
    // parent-dir traversal, non-empty.
    if (suggestedName.isEmpty ||
        suggestedName.contains('/') ||
        suggestedName.contains(r'\') ||
        suggestedName.contains('..')) {
      throw CustomButtonImageException('unsafe image name: "$suggestedName"');
    }
    final ext = _extensionOf(source.path);
    if (!allowedImageExtensions.contains(ext.toLowerCase())) {
      throw CustomButtonImageException('unsupported image type: $ext');
    }
    final length = await source.length();
    if (length > maxImageBytes) {
      throw CustomButtonImageException(
          'image too large ($length bytes, max $maxImageBytes)');
    }
    final dir = Directory('${(await _base()).path}/$imagesSubdir');
    if (!dir.existsSync()) await dir.create(recursive: true);
    final dest = File('${dir.path}/$suggestedName$ext');
    await source.copy(dest.path);
    return dest.path;
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.img';
    final ext = path.substring(dot);
    // Guard against a path with no real extension but a dot in a directory.
    return ext.contains('/') ? '.img' : ext;
  }
}
