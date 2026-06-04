/// Board-layout providers (ADR 0014).
///
/// Holds the parent-authored [BoardLayout] (position overrides) and the store
/// that persists it. `activeBoardProvider` and `editableBoardsProvider` apply it
/// via [applyLayout] AFTER custom buttons are merged.
///
/// Written with the manual Riverpod API (not the `@riverpod` codegen) on
/// purpose: it adds a provider without a build_runner pass, which would churn
/// the generated bandit/Isar `.g.dart` files.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';

final boardLayoutStoreProvider = Provider<BoardLayoutStore>(
  (ref) => BoardLayoutStore(),
);

final boardLayoutProvider =
    AsyncNotifierProvider<BoardLayoutNotifier, BoardLayout>(
  BoardLayoutNotifier.new,
);

class BoardLayoutNotifier extends AsyncNotifier<BoardLayout> {
  @override
  Future<BoardLayout> build() => ref.read(boardLayoutStoreProvider).load();

  /// Awaits the build (so an edit made before the initial load resolves is not
  /// clobbered by it), applies [transform] to the current layout, publishes it,
  /// then persists.
  Future<void> _update(BoardLayout Function(BoardLayout) transform) async {
    final current = await future;
    final next = transform(current);
    state = AsyncData(next);
    await ref.read(boardLayoutStoreProvider).save(next);
  }

  /// Pins [buttonId] on [boardId] to [position] (move onto an empty slot).
  Future<void> setPosition(
    String boardId,
    String buttonId,
    Position position,
  ) =>
      _update((c) => c.withPosition(boardId, buttonId, position));

  /// Commits a batch of position changes in one save (the drag-reorder commit).
  Future<void> setPositions(String boardId, Map<String, Position> positions) =>
      _update((c) => c.withPositions(boardId, positions));

  /// Exchanges the positions of two buttons (the swap gesture).
  Future<void> swap(
    String boardId,
    String idA,
    Position posA,
    String idB,
    Position posB,
  ) =>
      _update((c) => c.withSwap(boardId, idA, posA, idB, posB));

  /// Per-board reset to the default (bundled / creation-slot) layout.
  Future<void> resetBoard(String boardId) =>
      _update((c) => c.withoutBoard(boardId));

  /// Global reset: clears every board's overrides.
  Future<void> resetAll() => _update((_) => const BoardLayout.empty());
}
