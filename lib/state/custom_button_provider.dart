/// Custom-button providers (ADR 0012).
///
/// Exposes the persisted parent-authored buttons and the store that mutates
/// them. `activeBoardProvider` overlays the list onto the displayed board.
library;

import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'board_layout_provider.dart';
import 'board_stack.dart';
import 'icon_override_provider.dart';

part 'custom_button_provider.g.dart';

@Riverpod(keepAlive: true)
CustomButtonStore customButtonStore(CustomButtonStoreRef ref) =>
    CustomButtonStore();

/// Every known board with custom buttons already overlaid, for the editor to
/// show each board's display name and remaining empty slots. Re-resolves when
/// the custom-button list changes.
@riverpod
Future<List<AACBoard>> editableBoards(EditableBoardsRef ref) async {
  final registry = await ref.watch(boardRegistryProvider.future);
  final customs = ref.watch(customButtonsProvider).valueOrNull ?? const [];
  final layout =
      ref.watch(boardLayoutProvider).valueOrNull ?? const BoardLayout.empty();
  // The editor applies icon overrides (so a replaced picture shows here too) but
  // NOT the hidden filter: a parent must still see and un-hide a hidden tile
  // (ADR 0019). Hidden state is read directly by the editor for its grey badge.
  final iconOverrides =
      ref.watch(iconOverridesProvider).valueOrNull ?? const {};
  final boards = <AACBoard>[];
  for (final id in registry.knownBoardIds()) {
    try {
      final base = await registry.tryLoad(id);
      if (base != null) {
        boards.add(applyIconOverrides(
            applyLayout(applyCustomButtons(base, customs), layout),
            iconOverrides));
      }
    } catch (e) {
      // One unparseable board (e.g. a crafted import whose re-ided button id
      // exceeds the length cap, or any corrupt file) must NOT take down the
      // whole editor and the home favourites strip, which both derive from this
      // list. tryLoad rethrows parse failures, so isolate per board: skip the
      // bad one, load the rest. The import-time re-parse guard now prevents a
      // poison pack from being written at all; this contains any file that
      // predates that guard (review item 10).
      stderr.writeln('editableBoards: skipping unloadable board "$id": $e');
    }
  }
  return boards;
}

@Riverpod(keepAlive: true)
class CustomButtons extends _$CustomButtons {
  @override
  Future<List<CustomButton>> build() =>
      ref.read(customButtonStoreProvider).load();

  /// Copies [imageSource] (if any) into the persistent store, then adds a
  /// button at the given slot. Pass a null [imageSource] for a text-only
  /// button. Returns the new button's id once state reflects the new list, so
  /// the caller can attach a freshly recorded custom voice to it (ADR 0019).
  Future<String> addButton({
    required String boardId,
    required int row,
    required int col,
    required String label,
    String? voiceOut,
    File? imageSource,
  }) async {
    final store = ref.read(customButtonStoreProvider);
    final requested = (row: row, col: col);
    // Resolve the creation slot in BASE-board coordinates (P0-1). The editor
    // offers empty slots from the LAYOUT-COMPOSED board, but a custom button's
    // slot is merged onto the BASE board (applyCustomButtons, before applyLayout).
    // When the parent has rearranged the board, a slot empty in the display can be
    // occupied in the base, so storing the display slot verbatim used to evict the
    // base word there. Store a slot that is genuinely free in the base (+ existing
    // customs); if that differs from where the parent tapped, pin the new button
    // to the tapped slot with a layout override so it still appears exactly there.
    final creationSlot = await _baseFreeSlotFor(boardId, requested);

    // Reserve the stable id first (ADR 0014), then use it as the image
    // filename so the copied photo is named by identity, not by slot.
    final id = await store.allocateId(boardId);
    var imagePath = '';
    if (imageSource != null) {
      imagePath = await store.importImage(imageSource, suggestedName: id);
    }
    final button = CustomButton(
      id: id,
      boardId: boardId,
      row: creationSlot.row,
      col: creationSlot.col,
      label: label,
      voiceOut: (voiceOut == null || voiceOut.isEmpty) ? label : voiceOut,
      imagePath: imagePath,
    );
    state = AsyncData(await store.add(button));
    // Honour the tapped slot when the base-free creation slot differs from it:
    // an override displays the new button exactly where the parent placed it,
    // while its base creation slot stays collision-free.
    if (creationSlot != requested) {
      await ref
          .read(boardLayoutProvider.notifier)
          .setPositions(boardId, {id: requested});
    }
    return id;
  }

  /// The slot to STORE a new custom button at so it never collides with a live
  /// button on the base board (P0-1). Returns [requested] when it is free in the
  /// base (+ current customs); otherwise the first base-free slot; falling back
  /// to [requested] if the base board can't be loaded or is full (applyCustomButtons
  /// then relocates/handles it as a last resort).
  Future<Position> _baseFreeSlotFor(String boardId, Position requested) async {
    try {
      final registry = await ref.read(boardRegistryProvider.future);
      final base = await registry.tryLoad(boardId);
      if (base == null) return requested;
      final withCustoms =
          applyCustomButtons(base, state.valueOrNull ?? const <CustomButton>[]);
      final empties = withCustoms.emptySlots();
      if (empties.contains(requested)) return requested;
      return empties.isNotEmpty ? empties.first : requested;
    } catch (_) {
      return requested;
    }
  }

  Future<void> remove(String id) async {
    final store = ref.read(customButtonStoreProvider);
    state = AsyncData(await store.removeById(id));
  }

  /// Removes every custom button on [boardId] ("reset this board"). The id
  /// counter is preserved by the store so ids are never reused.
  Future<void> removeForBoard(String boardId) async {
    final store = ref.read(customButtonStoreProvider);
    state = AsyncData(await store.removeForBoard(boardId));
  }

  /// Removes every custom button across all boards ("reset everything").
  Future<void> resetAll() async {
    final store = ref.read(customButtonStoreProvider);
    state = AsyncData(await store.clearAll());
  }
}
