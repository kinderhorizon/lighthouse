/// Tile-visibility providers (ADR 0019).
///
/// Holds the parent-authored [HiddenTiles] overlay and its store.
/// `activeBoardProvider` applies it on the CHILD render path (dropping hidden
/// buttons); the editor reads it directly to grey-and-badge hidden tiles.
///
/// Written with the manual Riverpod API (not `@riverpod` codegen) on purpose,
/// like [boardLayoutProvider]: it adds a provider without a build_runner pass,
/// which would churn the generated bandit/Isar `.g.dart` files.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';

final hiddenTilesStoreProvider = Provider<HiddenTilesStore>(
  (ref) => HiddenTilesStore(),
);

final hiddenTilesProvider =
    AsyncNotifierProvider<HiddenTilesNotifier, HiddenTiles>(
  HiddenTilesNotifier.new,
);

class HiddenTilesNotifier extends AsyncNotifier<HiddenTiles> {
  @override
  Future<HiddenTiles> build() => ref.read(hiddenTilesStoreProvider).load();

  /// Awaits the build (so an edit made before the initial load resolves is not
  /// clobbered by it), applies [transform], publishes it, then persists.
  Future<void> _update(HiddenTiles Function(HiddenTiles) transform) async {
    final current = await future;
    final next = transform(current);
    state = AsyncData(next);
    await ref.read(hiddenTilesStoreProvider).save(next);
  }

  /// Hides (true) or shows (false) a single tile.
  Future<void> setHidden(String boardId, String buttonId, bool hidden) =>
      _update((c) => c.withVisibility(boardId, buttonId, hidden));

  /// Batch hide/show (the editor's select-mode action).
  Future<void> setHiddenBulk(
    String boardId,
    Iterable<String> buttonIds,
    bool hidden,
  ) =>
      _update((c) => c.withBulkVisibility(boardId, buttonIds, hidden));

  /// Per-board reset: un-hide every tile on [boardId].
  Future<void> resetBoard(String boardId) =>
      _update((c) => c.withoutBoard(boardId));

  /// Global reset: show everything on every board.
  Future<void> resetAll() => _update((_) => const HiddenTiles.empty());
}
