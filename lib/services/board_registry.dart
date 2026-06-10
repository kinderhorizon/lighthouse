/// Board registry.
///
/// Maps a `boardId` (e.g., "core_main", "board_food") to the source it can
/// be loaded from. The bundled default board is registered statically;
/// the Pack Loader registers imported sub-boards from filesystem paths at
/// runtime. [hydrate] rescans the persistent import directory at startup
/// so registrations survive across launches.
///
/// [tryLoad] returns null for unknown ids rather than throwing, because
/// "Pack not loaded" is an expected, recoverable UI state (PRD Default
/// Board Spec section 4.3: show a toast on missing target board, do not
/// crash the app).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'board_loader.dart';
import 'ota/content_overlay_store.dart';

class BoardRegistry {
  BoardRegistry({
    BoardLoader? loader,
    Directory? importedBoardsDirOverride,
    ContentOverlayStore? contentOverlay,
  })  : _loader = loader ?? const BoardLoader(),
        _dirOverride = importedBoardsDirOverride,
        _contentOverlay = contentOverlay;

  final BoardLoader _loader;
  final Directory? _dirOverride;

  /// OTA overlay (ADR 0017). When present, an overlaid `boards/<id>.json` wins
  /// over the bundled asset. Null = no OTA layer (bundled-only behavior).
  final ContentOverlayStore? _contentOverlay;

  /// Subdirectory name under the platform support directory for boards
  /// imported via the Pack Loader. Kept simple and platform-independent.
  static const String importSubdirName = 'imported_boards';

  /// Asset bundle paths for boards that ship with the app. Every folder
  /// link_id on the home board MUST resolve to one of these (the no-dead-folder
  /// invariant, asserted in board_registry_test). Adding a sub-board = a JSON
  /// file under boards/, a pubspec asset entry, and a row here.
  final Map<String, String> _assetSources = {
    'core_main': 'boards/core_main.json',
    'board_food': 'boards/board_food.json',
    'board_places': 'boards/board_places.json',
    'board_people': 'boards/board_people.json',
    'board_activities': 'boards/board_activities.json',
    'board_things': 'boards/board_things.json',
    'board_feelings': 'boards/board_feelings.json',
    'board_time': 'boards/board_time.json',
    'board_body': 'boards/board_body.json',
  };

  /// Filesystem paths for boards imported via the Pack Loader.
  final Map<String, String> _fileSources = {};

  /// Cached resolved import directory after first [_importedDir].
  Directory? _resolvedImportDir;

  Future<Directory> _importedDir() async {
    if (_resolvedImportDir != null) return _resolvedImportDir!;
    final base =
        _dirOverride ?? await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$importSubdirName');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _resolvedImportDir = dir;
    return dir;
  }

  /// Synchronous "do we know this id?" check. Used by the UI to decide
  /// whether to attempt load or short-circuit to the missing-pack toast.
  bool knows(String boardId) =>
      _assetSources.containsKey(boardId) ||
      _fileSources.containsKey(boardId);

  /// All board ids this registry can load (bundled + imported), in a stable
  /// order (assets first). The custom-button editor lists these.
  List<String> knownBoardIds() =>
      [..._assetSources.keys, ..._fileSources.keys];

  /// Attempts to load the board with [boardId]. Returns null if no source
  /// is registered for it. A registered source that fails to load
  /// rethrows the underlying [BoardLoadException] so the caller can
  /// surface the problem rather than silently treat it as "not loaded".
  Future<AACBoard?> tryLoad(String boardId) async {
    final board = await _loadRaw(boardId);
    if (board == null) return null;
    final overlay = _contentOverlay;
    if (overlay == null) return board;
    // Repoint any pictogram whose image was OTA-corrected to the overlay file
    // (ADR 0017). Applies whether the board itself was overlaid or bundled.
    return _overlayPictograms(board, overlay);
  }

  Future<AACBoard?> _loadRaw(String boardId) async {
    // OTA board overlay wins over the bundled asset (ADR 0017): a corrected
    // board JSON replaces the shipped one for the same id. Falls through to
    // bundled when no overlay (or no OTA layer) is present.
    final overlay = _contentOverlay;
    if (overlay != null) {
      final overlaid = await overlay.overlayFileFor('boards/$boardId.json');
      if (overlaid != null) {
        try {
          final board = await _loader.loadFromFile(overlaid);
          // ADR 0017 + item 8: a validly-signed overlay proves PROVENANCE, not
          // that it carries the right board. The device loads a board BY ID, and
          // custom buttons, layouts, and hidden tiles all key on board_id, so an
          // overlay whose declared board_id does not match the id we were asked
          // for would silently REPLACE a different board: it detaches that
          // board's customization and brings deliberately hidden tiles back to
          // the child. Treat an id mismatch exactly like a parse failure: keep
          // the overlay on disk (a later manifest can correct it) and fall back
          // to the bundled asset.
          if (board.boardId == boardId) return board;
          stderr.writeln('BoardRegistry: overlaid board "$boardId" declares '
              'mismatched board_id "${board.boardId}", falling back to the '
              'bundled asset.');
        } catch (e) {
          // An unparseable overlaid board must fall back to the bundled asset
          // rather than propagate an error screen, so "the grid for a
          // non-speaking child never breaks" (review item 11). Falls through to
          // the bundled / file sources below.
          stderr.writeln('BoardRegistry: overlaid board "$boardId" failed to '
              'parse, falling back to the bundled asset: $e');
        }
      }
    }

    final assetPath = _assetSources[boardId];
    if (assetPath != null) return _loader.loadFromAssets(assetPath);

    final filePath = _fileSources[boardId];
    if (filePath != null) return _loader.loadFromFile(File(filePath));

    return null;
  }

  Future<AACBoard> _overlayPictograms(
    AACBoard board,
    ContentOverlayStore overlay,
  ) async {
    final state = await overlay.readState();
    if (state.isEmpty) return board;
    const prefix = 'assets/';
    var changed = false;
    final out = <AACButton>[];
    for (final b in board.buttons) {
      if (b.iconUri.startsWith(prefix)) {
        final contentPath = b.iconUri.substring(prefix.length);
        if (state.files.contains(contentPath)) {
          final file = await overlay.overlayFileFor(contentPath);
          if (file != null) {
            out.add(b.withIconUri(file.path));
            changed = true;
            continue;
          }
        }
      }
      out.add(b);
    }
    return changed ? board.copyWithButtons(out) : board;
  }

  /// Register an additional asset-bundle source. Tests use this to wire
  /// fixtures; production startup registers the bundled core_main only.
  void registerAsset(String boardId, String assetPath) {
    _assetSources[boardId] = assetPath;
  }

  /// Register a board that lives on the filesystem (imported via the
  /// Pack Loader). The Pack Loader copies the source file into the
  /// persistent import directory and calls this with the destination
  /// path so the registration survives across launches.
  void registerFile(String boardId, String filePath) {
    _fileSources[boardId] = filePath;
  }

  /// Mints a fresh, unique imported `board_id` (ADR 0015) of the form
  /// `imported_<n>`, guaranteed not to collide with any board this registry
  /// already knows (bundled or previously imported). Used by the shared-vocab
  /// receive path so an incoming pack never overwrites a recipient board.
  String allocateImportedBoardId() {
    var n = _fileSources.length + 1;
    while (knows('imported_$n')) {
      n++;
    }
    return 'imported_$n';
  }

  /// Returns the persistent path the Pack Loader should copy imports to
  /// for a given [boardId]. The Pack Loader owns the copy semantics; the
  /// registry just answers "where should this end up?".
  Future<File> importDestinationFor(String boardId) async {
    final dir = await _importedDir();
    return File('${dir.path}/$boardId.json');
  }

  /// Scans the persistent import directory and registers every parseable
  /// JSON file under its board_id. Call once at startup. Errors on a
  /// single file are logged via stderr and skipped; one bad import never
  /// blocks others.
  Future<void> hydrate() async {
    final dir = await _importedDir();
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        // Cap the read the same way BoardLoader.loadFromFile does (4 MiB): this
        // hydrate path reads + decodes every imported file synchronously at
        // startup, so a tampered or corrupt oversized file could otherwise hang
        // or balloon launch. Skip + log; one bad file never blocks the others.
        final length = entity.lengthSync();
        if (length > BoardLoader.maxFileBytes) {
          stderr.writeln(
              'BoardRegistry.hydrate: skipping oversized import ${entity.path} '
              '($length bytes > ${BoardLoader.maxFileBytes})');
          continue;
        }
        final raw = entity.readAsStringSync();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final id = json['board_id'] as String?;
        // Skip ids that are absent or unsafe as a filename slug (the same guard
        // AACBoard.fromJson enforces on import; this covers files already on
        // disk from before the guard, or written by another path).
        if (id == null || id.isEmpty || !AACBoard.isValidBoardId(id)) continue;
        _fileSources[id] = entity.path;
      } catch (_) {
        // Skip malformed files; they will surface in the UI as missing
        // until the parent re-imports.
      }
    }
  }
}
