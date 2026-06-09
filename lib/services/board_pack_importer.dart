/// Pack Loader: import a board JSON the user supplies.
///
/// Validates that the source file parses as an [AACBoard], copies it
/// into the persistent import directory under the board's id, and
/// registers the new id with the [BoardRegistry]. PRD Tech Spec § 7.
///
/// The Pack Loader does NOT receive files from the OS share sheet today;
/// that surface (iOS UTI + Android intent-filter + a Dart-side intent
/// handler) is queued for a Phase 1 follow-up. For now, imports come
/// through the in-app file picker reachable from Settings.
library;

import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'board_loader.dart';
import 'board_registry.dart';

class BoardPackImportException implements Exception {
  const BoardPackImportException(this.message, {this.source, this.cause});

  final String message;
  final String? source;
  final Object? cause;

  @override
  String toString() {
    final src = source != null ? ' (source: $source)' : '';
    final c = cause != null ? '\nCaused by: $cause' : '';
    return 'BoardPackImportException: $message$src$c';
  }
}

class BoardPackImporter {
  BoardPackImporter({
    required this.registry,
    BoardLoader? loader,
  }) : _loader = loader ?? const BoardLoader();

  final BoardRegistry registry;
  final BoardLoader _loader;

  /// Reads [source], parses, persists into the registry's import dir,
  /// registers, and returns the resulting [AACBoard]. Throws
  /// [BoardPackImportException] on any failure; never silently treats a
  /// bad file as missing (which would surface as the wrong UI state).
  ///
  /// When [assignFreshId] is false (default, the original Pack Loader
  /// contract) the board keeps its own `board_id` and the source file is
  /// copied verbatim, so a folder `link_id` that targets this id still
  /// resolves.
  ///
  /// When [assignFreshId] is true (ADR 0015, the shared-vocabulary receive
  /// path) the board is given a fresh, unique `board_id` and every button id
  /// is namespaced, then written out re-ided. This lands the pack as a
  /// genuinely separate board, so importing a pack whose ids collide with the
  /// recipient's existing boards never overwrites them and never duplicates an
  /// id (preserving ADR 0009). The imported board starts cold: shared
  /// vocabulary transfers structure, not learning.
  Future<AACBoard> import(File source, {bool assignFreshId = false}) async {
    if (!source.existsSync()) {
      throw BoardPackImportException(
        'Source file does not exist',
        source: source.path,
      );
    }

    final AACBoard parsed;
    try {
      parsed = await _loader.loadFromFile(source);
    } catch (e) {
      throw BoardPackImportException(
        'Could not parse as a board',
        source: source.path,
        cause: e,
      );
    }

    // The only untrusted source of button ids is an imported pack. Board ids are
    // slug-validated, but button id / link_id are only length-checked
    // (aac_button.dart), so a crafted pack could carry a separator, `..`, NUL, or
    // the bandit state-key delimiters `|` / `:` and corrupt a learned-state key
    // or escape the per-id namespacing. Reject the whole pack rather than
    // rewrite (rewriting would break the pack's internal folder link references).
    // Bundled boards and the custom-button id generator never produce these.
    _validateImportedIds(parsed, source.path);

    final board = assignFreshId
        ? _reidentify(parsed, registry.allocateImportedBoardId())
        : _sanitizeIcons(parsed);

    // Re-parse the board we are about to persist. _reidentify prefixes every
    // button id (`<newBoardId>__`), which can push an already-long id (the
    // source passes fromJson at up to the 4096-char cap) PAST that cap. Persist
    // it anyway and the file throws on every future load: hydrate() registers it
    // on a board_id check alone, so the failure surfaces later in the board
    // loader, and editableBoards would brick the whole editor + favourites strip
    // on it. Validating the round-trip here fails the import loudly instead of
    // writing a file that can never be read (review item 10).
    try {
      AACBoard.fromJson(board.toJson());
    } catch (e) {
      throw BoardPackImportException(
        'Board pack could not be re-validated after import',
        source: source.path,
        cause: e,
      );
    }

    final dest = await registry.importDestinationFor(board.boardId);
    try {
      if (!dest.parent.existsSync()) {
        await dest.parent.create(recursive: true);
      }
      // Always write the parsed-and-sanitized board, never a verbatim byte copy:
      // the on-disk file must match the in-memory board so a re-parse on hydrate
      // cannot resurrect an unsafe (absolute) icon path, and icon safety no
      // longer depends on the caller passing assignFreshId (review L2). toJson
      // is the exact inverse of fromJson (ADR 0015), so this is lossless for
      // every other field, including a folder link_id that targets this id.
      await dest.writeAsString(jsonEncode(board.toJson()));
    } catch (e) {
      throw BoardPackImportException(
        'Could not write to persistent storage',
        source: source.path,
        cause: e,
      );
    }

    registry.registerFile(board.boardId, dest.path);
    return board;
  }

  /// Returns a copy of [board] under [newBoardId] with every button id (and any
  /// intra-pack folder `link_id`) namespaced by the new id, so the imported
  /// board owns a globally unique id space (ADR 0009). v1 export drops folders,
  /// so `link_id` rewriting is defensive.
  AACBoard _reidentify(AACBoard board, String newBoardId) {
    final prefix = '${newBoardId}__';
    return AACBoard(
      schemaVersion: board.schemaVersion,
      boardId: newBoardId,
      boardName: board.boardName,
      boardNameByLocale: board.boardNameByLocale,
      gridDimensions: board.gridDimensions,
      colorKey: board.colorKey,
      buttons: [
        for (final b in board.buttons)
          AACButton(
            id: '$prefix${b.id}',
            label: b.label,
            labelByLocale: b.labelByLocale,
            type: b.type,
            position: b.position,
            category: b.category,
            baseWeight: b.baseWeight,
            iconUri: _safeImportedIconUri(b.iconUri),
            voiceOut: b.voiceOut,
            voiceOutByLocale: b.voiceOutByLocale,
            linkId: b.linkId == null ? null : '$prefix${b.linkId}',
          ),
      ],
    );
  }

  /// Returns [board] with every button's icon constrained to a bundled-asset
  /// reference (absolute / non-asset paths blanked), board id and everything
  /// else unchanged. Applied on the verbatim import path so icon safety does
  /// not depend on the caller passing `assignFreshId` (the assignFreshId path
  /// applies the same rule per-button in _reidentify). See review L2.
  AACBoard _sanitizeIcons(AACBoard board) => board.copyWithButtons([
        for (final b in board.buttons)
          b.withIconUri(_safeImportedIconUri(b.iconUri)),
      ]);

  /// On the untrusted shared-pack receive path, an icon reference is kept only
  /// if it points at a bundled asset (`assets/...`). The exporter strips device
  /// photos (ADR 0015), so a legitimate pack carries only assets-relative icons
  /// or none; an absolute or otherwise non-asset path is a crafted reference to
  /// an arbitrary on-device file and is dropped (the button renders iconless
  /// rather than pointing the decoder at a path the sender chose). The OTA
  /// overlay (ADR 0017) repoints pictograms at render time, so this does not
  /// affect overlaid art.
  static String _safeImportedIconUri(String uri) =>
      uri.startsWith('assets/') ? uri : '';

  /// Forbidden characters in an imported button id / link_id: path separators,
  /// NUL, and the bandit state-key delimiters `|` and `:`. `..` is checked
  /// separately (it is a multi-char sequence, not a single class member).
  static final RegExp _forbiddenIdChars = RegExp(r'[/\\|:\x00]');

  /// Rejects the whole pack if any button id or link_id contains an unsafe
  /// character. Throws [BoardPackImportException]; the import is aborted before
  /// anything is persisted or registered.
  void _validateImportedIds(AACBoard board, String source) {
    bool unsafe(String? id) =>
        id != null && (_forbiddenIdChars.hasMatch(id) || id.contains('..'));
    for (final b in board.buttons) {
      if (unsafe(b.id) || unsafe(b.linkId)) {
        throw BoardPackImportException(
          'Board pack contains an unsafe button id or link id',
          source: source,
        );
      }
    }
  }
}
