/// Custom-button providers (ADR 0012, ADR 0022).
///
/// Exposes the persisted parent-authored buttons and the store that mutates
/// them. `activeBoardProvider` overlays the list onto the displayed board. A
/// parent-made category (ADR 0022) is a custom folder button whose page is
/// generated from it ([categoryBoardFor]); this file resolves those pages next
/// to the registry's boards.
library;

import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';
import '../services/services.dart';
import 'board_layout_provider.dart';
import 'board_stack.dart';
import 'custom_voice_provider.dart';
import 'favourites_provider.dart';
import 'hidden_tiles_provider.dart';
import 'icon_override_provider.dart';

part 'custom_button_provider.g.dart';

@Riverpod(keepAlive: true)
CustomButtonStore customButtonStore(CustomButtonStoreRef ref) =>
    CustomButtonStore();

/// Loads [boardId] from the registry (bundled, imported, OTA), or, failing
/// that, as a parent-made category page from [customs] (ADR 0022). Null when
/// neither knows it. The child's folder tap and the editor both resolve
/// through here, so a category opens the same way everywhere.
Future<AACBoard?> loadBoardOrCategory(
  BoardRegistry registry,
  String boardId,
  List<CustomButton> customs,
) async =>
    await registry.tryLoad(boardId) ?? categoryBoardById(boardId, customs);

/// A built-in button by board and id, straight from the registry (before any
/// parent change). Used for the word a parent's button replaced (ADR 0022):
/// that word is set aside, so it is absent from the composed boards.
final builtInButtonProvider = FutureProvider.autoDispose
    .family<AACButton?, ({String boardId, String buttonId})>((ref, key) async {
  final registry = await ref.watch(boardRegistryProvider.future);
  final board = await registry.tryLoad(key.boardId);
  return board?.buttons.where((b) => b.id == key.buttonId).firstOrNull;
});

/// Every known board with custom buttons already overlaid, for the editor to
/// show each board's display name and remaining empty slots. Re-resolves when
/// the custom-button list changes. Parent-made category pages (ADR 0022) come
/// after the registry's boards.
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
  AACBoard compose(AACBoard base) => applyIconOverrides(
      applyLayout(applyCustomButtons(base, customs), layout), iconOverrides);
  final boards = <AACBoard>[];
  for (final id in registry.knownBoardIds()) {
    try {
      final base = await registry.tryLoad(id);
      if (base != null) boards.add(compose(base));
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
  final known = {for (final b in boards) b.boardId};
  for (final c in customs) {
    final page = c.linkId;
    if (page != null && known.add(page)) boards.add(compose(categoryBoardFor(c)));
  }
  return boards;
}

@Riverpod(keepAlive: true)
class CustomButtons extends _$CustomButtons {
  @override
  Future<List<CustomButton>> build() =>
      ref.read(customButtonStoreProvider).load();

  /// Copies [imageSource] (if any) into the persistent store, then adds a
  /// button. Pass a null [imageSource] for a text-only button. [tileColor] is
  /// the parent's chosen colour (null = grey). Returns the new button's id once
  /// state reflects the new list, so the caller can attach a freshly recorded
  /// custom voice to it (ADR 0019).
  ///
  /// [row]/[col] is the slot the parent chose, as DISPLAYED in the editor.
  /// With [replacesId] (ADR 0022) the button takes the place of that built-in
  /// word, which is set aside until this button is deleted. With [category]
  /// true it is a category folder that opens a new blank page.
  Future<String> addButton({
    required String boardId,
    required int row,
    required int col,
    required String label,
    String? voiceOut,
    File? imageSource,
    TileColor? tileColor,
    String? replacesId,
    bool category = false,
  }) async {
    final store = ref.read(customButtonStoreProvider);
    final requested = (row: row, col: col);
    // Resolve the creation slot in BASE-board coordinates (P0-1). The editor
    // offers slots from the LAYOUT-COMPOSED board, but a custom button's slot is
    // merged onto the BASE board (applyCustomButtons, before applyLayout). When
    // the parent has rearranged the board, a slot empty in the display can be
    // occupied in the base, so storing the display slot verbatim used to evict
    // the base word there. Store a slot that is genuinely free in the base (+
    // existing customs), or the replaced word's own base slot; if that differs
    // from where the parent tapped, pin the new button to the tapped slot with a
    // layout override so it still appears exactly there.
    final creationSlot = replacesId == null
        ? await _baseFreeSlotFor(boardId, requested)
        : await _baseSlotOf(boardId, replacesId) ?? requested;

    // Reserve the stable id first (ADR 0014), then use it as the image
    // filename so the copied photo is named by identity, not by slot.
    final id = await store.allocateId(boardId);
    final linkId = category ? await store.allocateCategoryBoardId() : null;
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
      tileColor: tileColor,
      replacesId: replacesId,
      linkId: linkId,
    );
    state = AsyncData(await store.add(button));
    // Honour the tapped slot when the base creation slot differs from it: an
    // override displays the new button exactly where the parent placed it,
    // while its base creation slot stays collision-free.
    if (creationSlot != requested) {
      await ref
          .read(boardLayoutProvider.notifier)
          .setPositions(boardId, {id: requested});
    }
    return id;
  }

  /// Edits the custom button [id] (ADR 0022): its word or category name
  /// ([label], which is also what it says), its photo ([imageSource] for a new
  /// one, [removeImage] to go text-only) and its colour ([tileColor], null =
  /// grey). The id never changes, so its learning, pins, position and recorded
  /// voice stay with it. A no-op for an unknown id.
  Future<void> editButton(
    String id, {
    required String label,
    required TileColor? tileColor,
    File? imageSource,
    bool removeImage = false,
  }) async {
    final current = state.valueOrNull ?? await future;
    final existing = current.where((b) => b.id == id).firstOrNull;
    if (existing == null) return;
    final store = ref.read(customButtonStoreProvider);
    var imagePath = existing.imagePath;
    if (imageSource != null) {
      // A NEW filename, so no cached decode of the old photo can show through.
      imagePath = await store.importImage(imageSource,
          suggestedName: '${id}_${DateTime.now().millisecondsSinceEpoch}');
    } else if (removeImage) {
      imagePath = '';
    }
    final updated = CustomButton(
      id: existing.id,
      boardId: existing.boardId,
      row: existing.row,
      col: existing.col,
      label: label,
      voiceOut: label,
      imagePath: imagePath,
      tileColor: tileColor,
      replacesId: existing.replacesId,
      linkId: existing.linkId,
    );
    state = AsyncData(await store.update(updated));
    if (imagePath != existing.imagePath) {
      await store.deleteImage(existing.imagePath);
      // A picture picked for this tile earlier through "Replace picture" would
      // otherwise keep covering the photo the parent just chose.
      await _quietly(() => ref
          .read(iconOverridesProvider.notifier)
          .clear(existing.boardId, id));
    }
  }

  /// The slot to STORE a new custom button at so it never collides with a live
  /// button on the base board (P0-1). Returns [requested] when it is free in the
  /// base (+ current customs); otherwise the first base-free slot; falling back
  /// to [requested] if the base board can't be loaded or is full (applyCustomButtons
  /// then relocates/handles it as a last resort).
  Future<Position> _baseFreeSlotFor(String boardId, Position requested) async {
    try {
      final base = await _baseBoard(boardId);
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

  /// The BASE slot of the built-in word [buttonId] on [boardId], or null.
  Future<Position?> _baseSlotOf(String boardId, String buttonId) async {
    try {
      final base = await _baseBoard(boardId);
      return base?.buttons.where((b) => b.id == buttonId).firstOrNull?.position;
    } catch (_) {
      return null;
    }
  }

  /// [boardId] before any parent change: a registry board, or a blank
  /// parent-made category page.
  Future<AACBoard?> _baseBoard(String boardId) async {
    final registry = await ref.read(boardRegistryProvider.future);
    return loadBoardOrCategory(
        registry, boardId, state.valueOrNull ?? const <CustomButton>[]);
  }

  /// Deletes the custom button [id] and everything that only existed because of
  /// it (ADR 0022): for a category, every button on its page and on any
  /// category nested inside. For every deleted button its recorded voice and
  /// favourites pin go too, and for every deleted page its hidden, arrangement
  /// and picture settings. If the button had replaced a built-in word, that
  /// word comes back into the slot the button was in. Returns that word, if
  /// any, so the editor can say it is back.
  Future<AACButton?> remove(String id) async {
    final current = state.valueOrNull ?? await future;
    final button = current.where((b) => b.id == id).firstOrNull;
    if (button == null) return null;
    final subtree = customSubtree([id], current);

    // Where the button sits now, so a set-aside word returns to exactly that
    // slot (nothing else jumps, even if the parent has moved things since).
    AACButton? restored;
    final replaced = button.replacesId;
    if (replaced != null) {
      final board = await _quietly(() => _composedBoard(button.boardId));
      final now = board?.buttons.where((b) => b.id == id).firstOrNull;
      if (now != null) {
        await _quietly(() => ref
            .read(boardLayoutProvider.notifier)
            .setPositions(button.boardId, {replaced: now.position}));
      }
      final base = await _quietly(() => _baseBoard(button.boardId));
      restored = base?.buttons.where((b) => b.id == replaced).firstOrNull;
    }

    final store = ref.read(customButtonStoreProvider);
    final refs = [
      for (final c in current)
        if (subtree.buttonIds.contains(c.id)) (boardId: c.boardId, id: c.id),
    ];
    state = AsyncData(await store.removeMany(subtree.buttonIds));
    await _cleanUpAfterDelete(refs, subtree.boardIds);
    return restored;
  }

  /// Number of buttons that deleting the category [id] would also delete (its
  /// page and any nested category pages), for the confirm dialog.
  int buttonsInside(String id) {
    final current = state.valueOrNull ?? const <CustomButton>[];
    return customSubtree([id], current).buttonIds.length - 1;
  }

  /// [boardId] as the editor shows it (custom buttons + layout), for positions.
  Future<AACBoard?> _composedBoard(String boardId) async {
    final base = await _baseBoard(boardId);
    if (base == null) return null;
    final layout = await ref.read(boardLayoutProvider.future);
    return applyLayout(
        applyCustomButtons(base, state.valueOrNull ?? const []), layout);
  }

  /// Best-effort cleanup of what deleted buttons and pages leave elsewhere:
  /// recorded voices, favourites pins, and the pages' hidden, arrangement and
  /// picture settings. Each step is independent, so one failure cannot stop the
  /// rest or undo the delete itself. A child view sitting on a deleted page
  /// goes back to Home.
  Future<void> _cleanUpAfterDelete(
    List<({String boardId, String id})> deleted,
    Set<String> deletedPages,
  ) async {
    if (deleted.isEmpty) return;
    await _quietly(() => ref
        .read(customVoiceProvider.notifier)
        .removeMany(deleted.map((d) => d.id)));
    final pins = await _quietly(() => ref.read(favouritesProvider.future));
    final hidden = await _quietly(() => ref.read(hiddenTilesProvider.future));
    final icons = await _quietly(() => ref.read(iconOverridesProvider.future));
    for (final d in deleted) {
      if (pins == null ||
          !pins.any((p) => p.boardId == d.boardId && p.buttonId == d.id)) {
        continue;
      }
      await _quietly(
          () => ref.read(favouritesProvider.notifier).unpin(d.boardId, d.id));
    }
    // A deleted tile on a page that stays: drop its hidden flag and any picture
    // picked for it earlier ("Replace picture" stores a file per tile).
    for (final d in deleted) {
      if (deletedPages.contains(d.boardId)) continue;
      if (hidden?.isHidden(d.boardId, d.id) ?? false) {
        await _quietly(() => ref
            .read(hiddenTilesProvider.notifier)
            .setHidden(d.boardId, d.id, false));
      }
      if (icons?.containsKey(IconOverrideStore.key(d.boardId, d.id)) ?? false) {
        await _quietly(
            () => ref.read(iconOverridesProvider.notifier).clear(d.boardId, d.id));
      }
    }
    for (final page in deletedPages) {
      await _quietly(
          () => ref.read(hiddenTilesProvider.notifier).resetBoard(page));
      await _quietly(
          () => ref.read(boardLayoutProvider.notifier).resetBoard(page));
      await _quietly(
          () => ref.read(iconOverridesProvider.notifier).resetBoard(page));
    }
    if (deletedPages.isNotEmpty &&
        ref.read(boardStackProvider).any((b) => deletedPages.contains(b.boardId))) {
      ref.read(boardStackProvider.notifier).resetToRoot();
    }
  }

  static Future<T?> _quietly<T>(Future<T> Function() step) async {
    try {
      return await step();
    } catch (e) {
      stderr.writeln('CustomButtons: cleanup step failed: $e');
      return null;
    }
  }

  /// Removes every custom button on [boardId] ("reset this board"), with the
  /// same cascade as [remove] for categories on it (ADR 0022). The id counter
  /// is preserved by the store so ids are never reused. Set-aside words come
  /// back on their own: the reset also clears this board's arrangement.
  Future<void> removeForBoard(String boardId) async {
    final current = state.valueOrNull ?? await future;
    final subtree = customSubtree(
        [for (final c in current) if (c.boardId == boardId) c.id], current);
    final refs = [
      for (final c in current)
        if (subtree.buttonIds.contains(c.id)) (boardId: c.boardId, id: c.id),
    ];
    final store = ref.read(customButtonStoreProvider);
    state = AsyncData(await store.removeMany(subtree.buttonIds));
    await _cleanUpAfterDelete(refs, subtree.boardIds);
  }

  /// Removes every custom button across all boards ("reset everything").
  Future<void> resetAll() async {
    final current = state.valueOrNull ?? await future;
    final pages = {
      for (final c in current)
        if (c.linkId != null) c.linkId!,
    };
    final store = ref.read(customButtonStoreProvider);
    state = AsyncData(await store.clearAll());
    // Every parent-made category page is gone: a child view sitting on one
    // goes back to Home (ADR 0022).
    if (pages.isNotEmpty &&
        ref.read(boardStackProvider).any((b) => pages.contains(b.boardId))) {
      ref.read(boardStackProvider.notifier).resetToRoot();
    }
  }
}
