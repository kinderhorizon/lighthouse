/// Board navigation stack.
///
/// Tracks the chain of boards the user has navigated into. The root entry
/// is the default Home Core 48; folder taps push a sub-board on top; back
/// taps pop. The stack is intentionally a small immutable list rather than
/// a Navigator-managed route stack because boards live below the Material
/// route system (the same Scaffold hosts the grid throughout) and the
/// Settings UI later will want to read depth without route-tree spelunking.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'board_layout_provider.dart';
import 'board_provider.dart';
import 'content_overlay_provider.dart';
import 'custom_button_provider.dart';
import 'hidden_tiles_provider.dart';
import 'icon_override_provider.dart';

part 'board_stack.g.dart';

/// Async because the registry hydrates from the persistent import
/// directory on startup so imported sub-boards survive across app
/// launches.
@Riverpod(keepAlive: true)
Future<BoardRegistry> boardRegistry(BoardRegistryRef ref) async {
  // Share the one overlay store so the registry READS overlaid boards that the
  // ContentUpdateService WROTE (ADR 0017).
  final registry =
      BoardRegistry(contentOverlay: ref.watch(contentOverlayStoreProvider));
  await registry.hydrate();
  return registry;
}

@Riverpod(keepAlive: true)
class BoardStack extends _$BoardStack {
  @override
  List<AACBoard> build() {
    // Initial state: empty until the default board resolves. The UI shows
    // the FutureProvider's loading state until then; once the default
    // board lands the stack is seeded with it via [_seed].
    final initial = ref.watch(defaultBoardProvider).valueOrNull;
    return initial == null ? const [] : [initial];
  }

  /// Number of boards currently on the stack. 0 if the default board has
  /// not loaded yet, 1 at the home board, >1 inside folders.
  int get depth => state.length;

  /// Pushes [board] on top of the stack.
  void push(AACBoard board) {
    state = [...state, board];
  }

  /// Pops the top of the stack. No-op when at the root, so callers can
  /// always call pop without checking depth.
  void pop() {
    if (state.length <= 1) return;
    state = state.sublist(0, state.length - 1);
  }

  /// Drops everything except the root. Used by Settings "Return to home".
  void resetToRoot() {
    if (state.length <= 1) return;
    state = state.sublist(0, 1);
  }
}

@riverpod
AACBoard? activeBoard(ActiveBoardRef ref) {
  final stack = ref.watch(boardStackProvider);
  if (stack.isEmpty) return null;
  // Overlay parent-authored custom buttons (ADR 0012) then the layout overrides
  // (ADR 0014) onto whatever board is on top. Single integration point: every
  // consumer (grid, glow predictions) sees the merged board, while the stack
  // itself stays pure bundled boards. Composition order is bundled -> custom ->
  // layout (the layout only moves positions, never ids/categories).
  final customs = ref.watch(customButtonsProvider).valueOrNull ?? const [];
  final layout =
      ref.watch(boardLayoutProvider).valueOrNull ?? const BoardLayout.empty();
  // ADR 0019: a parent's chosen pictures override the bundled/custom art, and
  // hidden tiles are dropped from the CHILD board (their slot renders empty,
  // every other tile keeps its position). Order: bundled -> custom -> layout
  // (positions) -> icon overrides (art) -> hidden (drop). Hidden is LAST and is
  // applied here only; the editor (editableBoardsProvider) shows hidden tiles.
  final iconOverrides =
      ref.watch(iconOverridesProvider).valueOrNull ?? const {};
  final hidden =
      ref.watch(hiddenTilesProvider).valueOrNull ?? const HiddenTiles.empty();
  final placed = applyLayout(applyCustomButtons(stack.last, customs), layout);
  return applyHiddenTiles(applyIconOverrides(placed, iconOverrides), hidden);
}
