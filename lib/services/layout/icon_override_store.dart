/// Persistence for parent-chosen tile pictures (ADR 0019, "Replace picture").
///
/// Stores a per-board `buttonId -> image filename` map as one JSON file, and the
/// chosen images in a sibling `icon_overrides/` directory, both under the app
/// support directory (the SAME backup-excluded location as the rest of the
/// parent-authored board customization, ADR 0002 / 0012 / 0013 / 0014).
///
/// Applied at read time in `activeBoardProvider` (child) AND
/// `editableBoardsProvider` (editor) by repointing the button's `icon_uri` via
/// [AACButton.withIconUri], which never touches the button's id or category, so
/// bandit learning and glow are unaffected (ADR 0014 / 0017). Overriding only
/// changes which image renders; "reset this board" clears it.
///
/// Keyed by (boardId, buttonId): a button id is unique within a board, and the
/// same id can recur across boards, so the board scopes the override exactly
/// like a favourite ref (ADR 0013). A corrupt file loads as no overrides.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';
import '../custom/custom_button_store.dart' show CustomButtonStore;
import '../util/atomic_file.dart';

/// Repoints each button on [board] whose (boardId, buttonId) has a parent-chosen
/// picture (ADR 0019) at the override image, via [AACButton.withIconUri] (which
/// preserves id/category, so bandit + glow are untouched). [overridesByKey] is
/// keyed by [IconOverrideStore.key]. Applied on BOTH the child and editor paths.
AACBoard applyIconOverrides(
  AACBoard board,
  Map<String, String> overridesByKey,
) {
  if (overridesByKey.isEmpty) return board;
  var changed = false;
  final next = <AACButton>[];
  for (final b in board.buttons) {
    final path = overridesByKey[IconOverrideStore.key(board.boardId, b.id)];
    if (path != null && path != b.iconUri) {
      next.add(b.withIconUri(path));
      changed = true;
    } else {
      next.add(b);
    }
  }
  return changed ? board.copyWithButtons(next) : board;
}

/// Thrown by [IconOverrideStore.setImage] when a picked image is too large or
/// not a recognized image type. Reuses the custom-button image caps.
class IconOverrideException implements Exception {
  const IconOverrideException(this.message);
  final String message;
  @override
  String toString() => 'IconOverrideException: $message';
}

class IconOverrideStore {
  IconOverrideStore({Directory? dirOverride}) : _dirOverride = dirOverride;

  final Directory? _dirOverride;

  static const String fileName = 'icon_overrides.json';
  static const String imagesSubdir = 'icon_overrides';

  /// Composite key so a flat in-memory map can be looked up by (board, button)
  /// at render time. The NUL separator cannot occur in a board or button id.
  static String key(String boardId, String buttonId) =>
      '$boardId\u0000$buttonId';

  Directory? _resolvedBase;

  Future<Directory> _base() async {
    if (_resolvedBase != null) return _resolvedBase!;
    final base = _dirOverride ?? await getApplicationSupportDirectory();
    if (!base.existsSync()) await base.create(recursive: true);
    _resolvedBase = base;
    return base;
  }

  Future<File> _file() async => File('${(await _base()).path}/$fileName');

  String _imagesDirPath(Directory base) => '${base.path}/$imagesSubdir';

  /// Raw nested `{boardId: {buttonId: filename}}`, filenames as stored.
  Future<Map<String, Map<String, String>>> _readRaw() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return {};
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return {};
      final out = <String, Map<String, String>>{};
      for (final boardEntry in raw.entries) {
        final v = boardEntry.value;
        if (v is! Map) continue;
        final inner = <String, String>{
          for (final e in v.entries)
            if (e.value is String && (e.value as String).isNotEmpty)
              e.key.toString(): e.value as String,
        };
        if (inner.isNotEmpty) out[boardEntry.key.toString()] = inner;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// Loads overrides as a flat `key(boardId,buttonId) -> absolute image path`
  /// map, resolved against the live images directory (so the path survives a
  /// reinstall / restore, like custom-button images).
  Future<Map<String, String>> load() async {
    final raw = await _readRaw();
    final dir = _imagesDirPath(await _base());
    final out = <String, String>{};
    for (final boardEntry in raw.entries) {
      for (final e in boardEntry.value.entries) {
        out[key(boardEntry.key, e.key)] = '$dir/${e.value}';
      }
    }
    return out;
  }

  Future<void> _write(Map<String, Map<String, String>> raw) async {
    final f = await _file();
    await writeStringAtomically(f, jsonEncode(raw));
  }

  /// Copies [source] into the images directory, sets it as the picture for
  /// (boardId, buttonId), and returns the updated flat absolute-path map.
  Future<Map<String, String>> setImage(
    File source, {
    required String boardId,
    required String buttonId,
  }) async {
    if (boardId.isEmpty ||
        buttonId.isEmpty ||
        buttonId.contains('/') ||
        buttonId.contains(r'\') ||
        buttonId.contains('..') ||
        boardId.contains('/') ||
        boardId.contains('..')) {
      throw IconOverrideException('unsafe id: "$boardId/$buttonId"');
    }
    final ext = _extensionOf(source.path).toLowerCase();
    if (!CustomButtonStore.allowedImageExtensions.contains(ext)) {
      throw IconOverrideException('unsupported image type: $ext');
    }
    if (await source.length() > CustomButtonStore.maxImageBytes) {
      throw const IconOverrideException('image too large');
    }
    final base = await _base();
    final dir = Directory(_imagesDirPath(base));
    if (!dir.existsSync()) await dir.create(recursive: true);

    final raw = await _readRaw();
    final inner = raw[boardId];
    final prior = inner?[buttonId];
    // Only resolve a stored filename for deletion if it is a bare basename;
    // a locally-tampered entry with a separator or `..` is ignored (bounds an
    // arbitrary-delete to this store's own directory).
    if (prior != null && CustomButtonStore.isSafeStoredName(prior)) {
      await _deleteQuietly(File('${dir.path}/$prior'));
    }

    // Sanitised, board-scoped filename so two boards' overrides cannot collide.
    final name = '${boardId}__$buttonId$ext';
    await source.copy('${dir.path}/$name');
    final next = {
      for (final e in raw.entries) e.key: {...e.value},
    };
    (next[boardId] ??= {})[buttonId] = name;
    await _write(next);
    return load();
  }

  /// Clears the override for (boardId, buttonId), deleting its image, and
  /// returns the updated map. Restores the bundled/custom pictogram.
  Future<Map<String, String>> clear(String boardId, String buttonId) async {
    final raw = await _readRaw();
    final inner = raw[boardId];
    final name = inner?[buttonId];
    if (name == null) return load();
    if (CustomButtonStore.isSafeStoredName(name)) {
      await _deleteQuietly(File('${_imagesDirPath(await _base())}/$name'));
    }
    final next = {
      for (final e in raw.entries) e.key: {...e.value},
    };
    next[boardId]!.remove(buttonId);
    if (next[boardId]!.isEmpty) next.remove(boardId);
    await _write(next);
    return load();
  }

  /// Clears EVERY picture override on [boardId] (deleting their images) and
  /// returns the updated map. Used by the editor's "reset this board".
  Future<Map<String, String>> resetBoard(String boardId) async {
    final raw = await _readRaw();
    final inner = raw[boardId];
    if (inner == null || inner.isEmpty) return load();
    final dir = _imagesDirPath(await _base());
    for (final name in inner.values) {
      if (CustomButtonStore.isSafeStoredName(name)) {
        await _deleteQuietly(File('$dir/$name'));
      }
    }
    final next = {
      for (final e in raw.entries)
        if (e.key != boardId) e.key: {...e.value},
    };
    await _write(next);
    return load();
  }

  /// Clears ALL picture overrides across every board (deleting their images).
  /// Used by the editor's "reset everything".
  Future<Map<String, String>> resetAll() async {
    final dir = Directory(_imagesDirPath(await _base()));
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {/* best-effort */}
    }
    await _write(<String, Map<String, String>>{});
    return load();
  }

  static Future<void> _deleteQuietly(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } catch (_) {/* best-effort */}
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.img';
    final ext = path.substring(dot);
    return ext.contains('/') ? '.img' : ext;
  }
}
