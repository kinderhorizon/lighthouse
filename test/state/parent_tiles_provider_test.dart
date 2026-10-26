/// Parent-made tiles through the real providers (ADR 0022): add a coloured
/// button, a category and a replacement; edit; delete with the cascade; the
/// set-aside word coming back into the slot the new button was in; and what
/// the child view and editor actually render. In-memory stores, a fake
/// registry, real composition.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';

import '../support/fake_stores.dart';

class _FakeRegistry extends BoardRegistry {
  _FakeRegistry(this.boards);
  final Map<String, AACBoard> boards;
  @override
  Future<AACBoard?> tryLoad(String boardId) async => boards[boardId];
  @override
  List<String> knownBoardIds() => boards.keys.toList();
  @override
  bool knows(String boardId) => boards.containsKey(boardId);
}

AACButton _word(String id, int row, int col) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: 'food',
      baseWeight: 0.5,
      iconUri: '',
      voiceOut: id,
    );

/// A FULL 2x3 Home: five words and a folder into Food.
AACBoard _home() => AACBoard(
      schemaVersion: '1.3',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 2, cols: 3),
      colorKey: const {'food': '#FFD9A6', 'verb': '#C2FFC2'},
      buttons: [
        _word('want', 0, 0),
        _word('eat', 0, 1),
        _word('drink', 0, 2),
        _word('more', 1, 0),
        _word('stop', 1, 1),
        const AACButton(
          id: 'fld_food',
          label: 'Food',
          labelByLocale: {},
          type: AACButtonType.folder,
          position: (row: 1, col: 2),
          category: 'food_nav',
          baseWeight: 0.5,
          iconUri: '',
          linkId: 'board_food',
        ),
      ],
    );

AACBoard _food() => AACBoard(
      schemaVersion: '1.3',
      boardId: 'board_food',
      boardName: 'Food',
      gridDimensions: (rows: 2, cols: 2),
      colorKey: const {'food': '#FFD9A6'},
      buttons: [_word('apple', 0, 0)],
    );

class _Harness {
  _Harness() {
    container = ProviderContainer(overrides: [
      boardRegistryProvider
          .overrideWith((ref) async => _FakeRegistry({
                'core_main': _home(),
                'board_food': _food(),
              })),
      ...fakeStoreOverrides(
        buttons: buttons,
        voices: voices,
        favourites: favs,
        hidden: hidden,
        layout: layout,
        icons: icons,
      ),
    ]);
    // Keep the auto-dispose editor list alive for the whole test.
    container.listen(editableBoardsProvider, (_, __) {});
  }

  final buttons = FakeCustomButtonStore();
  final voices = FakeVoiceStore();
  final favs = FakeFavStore();
  final hidden = FakeHiddenStore();
  final layout = FakeLayoutStore();
  final icons = FakeIconStore();
  late final ProviderContainer container;

  CustomButtons get notifier => container.read(customButtonsProvider.notifier);

  Future<void> ready() async {
    await container.read(customButtonsProvider.future);
    await container.read(boardLayoutProvider.future);
    await container.read(hiddenTilesProvider.future);
    await container.read(favouritesProvider.future);
    await container.read(customVoiceProvider.future);
    await container.read(iconOverridesProvider.future);
    await container.read(defaultBoardProvider.future);
  }

  Future<AACBoard> editorBoard(String id) async {
    final boards = await container.read(editableBoardsProvider.future);
    return boards.firstWhere((b) => b.boardId == id);
  }

  /// What the CHILD sees for the top of the stack.
  AACBoard child() => container.read(activeBoardProvider)!;
}

void main() {
  late _Harness h;
  setUp(() async {
    h = _Harness();
    await h.ready();
  });
  tearDown(() => h.container.dispose());

  test('a new coloured button lands where the parent tapped, in its colour',
      () async {
    final id = await h.notifier.addButton(
        boardId: 'board_food', row: 1, col: 1, label: 'Pizza',
        tileColor: TileColor.orange);
    final food = await h.editorBoard('board_food');
    final pizza = food.buttonAt((row: 1, col: 1))!;
    expect(pizza.id, id);
    expect(pizza.tileColor, TileColor.orange);
    expect(pizza.category, kCustomCategory);
  });

  group('categories', () {
    test('adding a category makes a folder and a blank page named after it',
        () async {
      final id = await h.notifier.addButton(
          boardId: 'board_food', row: 0, col: 1, label: 'Snacks',
          tileColor: TileColor.green, category: true);
      final food = await h.editorBoard('board_food');
      final folder = food.buttons.firstWhere((b) => b.id == id);
      expect(folder.type, AACButtonType.folder);
      expect(folder.linkId, 'cat_0');
      expect(folder.tileColor, TileColor.green);

      final page = await h.editorBoard('cat_0');
      expect(page.boardName, 'Snacks');
      expect(page.buttons, isEmpty);
      // The child opens it the same way the editor does.
      final registry = await h.container.read(boardRegistryProvider.future);
      final opened = await loadBoardOrCategory(
          registry, 'cat_0', h.container.read(customButtonsProvider).value!);
      expect(opened?.boardName, 'Snacks');
    });

    test('words added inside a category show on its page, for the child too',
        () async {
      await h.notifier.addButton(
          boardId: 'board_food', row: 0, col: 1, label: 'Snacks', category: true);
      await h.notifier.addButton(
          boardId: 'cat_0', row: 0, col: 0, label: 'Crackers',
          tileColor: TileColor.green);
      final page = await h.editorBoard('cat_0');
      expect(page.buttonAt((row: 0, col: 0))?.label, 'Crackers');

      final registry = await h.container.read(boardRegistryProvider.future);
      final opened = await loadBoardOrCategory(
          registry, 'cat_0', h.container.read(customButtonsProvider).value!);
      h.container.read(boardStackProvider.notifier).push(opened!);
      expect(h.child().boardId, 'cat_0');
      expect(h.child().buttonAt((row: 0, col: 0))?.label, 'Crackers');
    });

    test('deleting a category deletes everything that only existed for it',
        () async {
      final snacks = await h.notifier.addButton(
          boardId: 'board_food', row: 0, col: 1, label: 'Snacks', category: true);
      final crackers = await h.notifier.addButton(
          boardId: 'cat_0', row: 0, col: 0, label: 'Crackers');
      final sweet = await h.notifier.addButton(
          boardId: 'cat_0', row: 0, col: 1, label: 'Sweet', category: true);
      final cake = await h.notifier.addButton(
          boardId: 'cat_1', row: 0, col: 0, label: 'Cake');
      final keep = await h.notifier.addButton(
          boardId: 'board_food', row: 1, col: 0, label: 'Keep');
      // Settings that only belong to the deleted pages / buttons.
      await h.container
          .read(customVoiceProvider.notifier)
          .save(crackers, File('x'));
      await h.container.read(favouritesProvider.notifier).pin('cat_0', crackers);
      await h.container.read(favouritesProvider.notifier).pin('board_food', keep);
      await h.container
          .read(hiddenTilesProvider.notifier)
          .setHidden('cat_1', cake, true);
      await h.container
          .read(boardLayoutProvider.notifier)
          .setPositions('cat_0', {crackers: (row: 2, col: 2)});

      expect(h.notifier.buttonsInside(snacks), 3);
      await h.notifier.remove(snacks);

      final left = h.container.read(customButtonsProvider).value!;
      expect(left.map((b) => b.id), [keep]);
      expect(h.voices.m.containsKey(crackers), isFalse);
      expect(h.favs.pinsList,
          [(boardId: 'board_food', buttonId: keep)]);
      expect(h.hidden.h.forBoard('cat_1'), isEmpty);
      expect(h.layout.l.forBoard('cat_0'), isEmpty);
      final boards = await h.container.read(editableBoardsProvider.future);
      expect(boards.map((b) => b.boardId),
          isNot(anyOf(contains('cat_0'), contains('cat_1'))));
      expect(sweet, isNotNull);
    });

    test('a child sitting on a deleted category page goes back to Home',
        () async {
      final snacks = await h.notifier.addButton(
          boardId: 'board_food', row: 0, col: 1, label: 'Snacks', category: true);
      final registry = await h.container.read(boardRegistryProvider.future);
      final page = await loadBoardOrCategory(
          registry, 'cat_0', h.container.read(customButtonsProvider).value!);
      h.container.read(boardStackProvider.notifier).push(_food());
      h.container.read(boardStackProvider.notifier).push(page!);
      await h.notifier.remove(snacks);
      expect(h.container.read(boardStackProvider).map((b) => b.boardId),
          ['core_main']);
    });

    test('reset this board takes its categories with it', () async {
      await h.notifier.addButton(
          boardId: 'board_food', row: 0, col: 1, label: 'Snacks', category: true);
      await h.notifier.addButton(boardId: 'cat_0', row: 0, col: 0, label: 'X');
      await h.notifier.addButton(boardId: 'core_main', row: 0, col: 0,
          label: 'Mine', replacesId: 'want');
      await h.notifier.removeForBoard('board_food');
      final left = h.container.read(customButtonsProvider).value!;
      expect(left.map((b) => b.label), ['Mine']);
    });

    test('reset everything sends a child on a category page back to Home',
        () async {
      await h.notifier.addButton(
          boardId: 'board_food', row: 0, col: 1, label: 'Snacks', category: true);
      final registry = await h.container.read(boardRegistryProvider.future);
      final page = await loadBoardOrCategory(
          registry, 'cat_0', h.container.read(customButtonsProvider).value!);
      h.container.read(boardStackProvider.notifier).push(page!);
      await h.notifier.resetAll();
      expect(h.container.read(boardStackProvider).map((b) => b.boardId),
          ['core_main']);
    });
  });

  group('replacing a word on a full page', () {
    test('the new button takes the word\'s exact spot; nothing else moves',
        () async {
      final before = await h.editorBoard('core_main');
      final id = await h.notifier.addButton(
          boardId: 'core_main', row: 0, col: 1, label: 'Pizza',
          replacesId: 'eat');
      final after = await h.editorBoard('core_main');
      expect(after.buttonAt((row: 0, col: 1))?.id, id);
      expect(after.buttons.any((b) => b.id == 'eat'), isFalse);
      for (final b in before.buttons.where((b) => b.id != 'eat')) {
        expect(after.buttons.firstWhere((x) => x.id == b.id).position,
            b.position, reason: '${b.id} must not move');
      }
      // The child sees the same.
      expect(h.child().buttonAt((row: 0, col: 1))?.id, id);
    });

    test('on a rearranged board it appears where the word was DISPLAYED',
        () async {
      // The parent dragged "eat" and "more" around: eat now shows at (1,0).
      await h.container.read(boardLayoutProvider.notifier).setPositions(
          'core_main', {'eat': (row: 1, col: 0), 'more': (row: 0, col: 1)});
      final shown = await h.editorBoard('core_main');
      expect(shown.buttonAt((row: 1, col: 0))?.id, 'eat');

      final id = await h.notifier.addButton(
          boardId: 'core_main', row: 1, col: 0, label: 'Pizza',
          replacesId: 'eat');
      final after = await h.editorBoard('core_main');
      expect(after.buttonAt((row: 1, col: 0))?.id, id);
      expect(after.buttonAt((row: 0, col: 1))?.id, 'more');
      expect(after.buttons.any((b) => b.id == 'eat'), isFalse);
    });

    test('deleting it brings the word back, into the spot it was in', () async {
      final id = await h.notifier.addButton(
          boardId: 'core_main', row: 0, col: 1, label: 'Pizza',
          replacesId: 'eat');
      final back = await h.notifier.remove(id);
      expect(back?.id, 'eat');
      final after = await h.editorBoard('core_main');
      expect(after.buttonAt((row: 0, col: 1))?.id, 'eat');
    });

    test('if the parent moved their button, the word comes back THERE and '
        'nothing else jumps', () async {
      final id = await h.notifier.addButton(
          boardId: 'core_main', row: 0, col: 1, label: 'Pizza',
          replacesId: 'eat');
      // The parent swaps Pizza with "stop".
      await h.container.read(boardLayoutProvider.notifier).setPositions(
          'core_main', {id: (row: 1, col: 1), 'stop': (row: 0, col: 1)});
      final moved = await h.editorBoard('core_main');
      expect(moved.buttonAt((row: 1, col: 1))?.id, id);

      await h.notifier.remove(id);
      final after = await h.editorBoard('core_main');
      expect(after.buttonAt((row: 1, col: 1))?.id, 'eat');
      expect(after.buttonAt((row: 0, col: 1))?.id, 'stop');
      expect(after.buttonAt((row: 0, col: 0))?.id, 'want');
    });

    test('a hidden word stays hidden when it comes back (start-blank flow)',
        () async {
      await h.container
          .read(hiddenTilesProvider.notifier)
          .setHidden('core_main', 'eat', true);
      final id = await h.notifier.addButton(
          boardId: 'core_main', row: 0, col: 1, label: 'Pizza',
          replacesId: 'eat');
      // The new button is visible to the child.
      expect(h.child().buttonAt((row: 0, col: 1))?.id, id);
      await h.notifier.remove(id);
      // "eat" is back in the editor but still hidden from the child.
      expect((await h.editorBoard('core_main')).buttonAt((row: 0, col: 1))?.id,
          'eat');
      expect(h.child().buttonAt((row: 0, col: 1)), isNull);
    });

    test('a category can replace a word too', () async {
      final id = await h.notifier.addButton(
          boardId: 'core_main', row: 1, col: 1, label: 'School',
          replacesId: 'stop', category: true, tileColor: TileColor.yellow);
      final after = await h.editorBoard('core_main');
      final folder = after.buttonAt((row: 1, col: 1))!;
      expect(folder.id, id);
      expect(folder.type, AACButtonType.folder);
      expect(after.buttons.any((b) => b.id == 'stop'), isFalse);
      await h.notifier.remove(id);
      expect((await h.editorBoard('core_main')).buttonAt((row: 1, col: 1))?.id,
          'stop');
    });
  });

  group('edit', () {
    test('word, colour and voice text change; id, slot, voice and pin stay',
        () async {
      final id = await h.notifier.addButton(
          boardId: 'board_food', row: 1, col: 1, label: 'Piza');
      await h.container.read(favouritesProvider.notifier).pin('board_food', id);
      await h.notifier.editButton(id, label: 'Pizza', tileColor: TileColor.orange);
      final b = h.container.read(customButtonsProvider).value!.single;
      expect(b.id, id);
      expect(b.label, 'Pizza');
      expect(b.voiceOut, 'Pizza');
      expect(b.tileColor, TileColor.orange);
      expect((b.row, b.col), (1, 1));
      expect(h.favs.pinsList, [(boardId: 'board_food', buttonId: id)]);
    });

    test('back to grey clears the colour', () async {
      final id = await h.notifier.addButton(
          boardId: 'board_food', row: 1, col: 1, label: 'X',
          tileColor: TileColor.blue);
      await h.notifier.editButton(id, label: 'X', tileColor: null);
      expect(h.container.read(customButtonsProvider).value!.single.tileColor,
          isNull);
    });

    test('a new photo gets a new file, the old one is deleted, and an older '
        '"replace picture" no longer covers it', () async {
      final id = await h.notifier.addButton(
          boardId: 'board_food', row: 1, col: 1, label: 'X',
          imageSource: File('a.png'));
      final first = h.container.read(customButtonsProvider).value!.single;
      expect(first.imagePath, isNotEmpty);
      await h.container
          .read(iconOverridesProvider.notifier)
          .setImage('board_food', id, File('b.png'));
      await h.notifier.editButton(id,
          label: 'X', tileColor: null, imageSource: File('c.png'));
      final second = h.container.read(customButtonsProvider).value!.single;
      expect(second.imagePath, isNot(first.imagePath));
      expect(h.buttons.deletedImages, [first.imagePath]);
      expect(h.icons.m.containsKey(IconOverrideStore.key('board_food', id)),
          isFalse);
    });

    test('remove photo makes it text-only', () async {
      final id = await h.notifier.addButton(
          boardId: 'board_food', row: 1, col: 1, label: 'X',
          imageSource: File('a.png'));
      final path = h.container.read(customButtonsProvider).value!.single.imagePath;
      await h.notifier.editButton(id, label: 'X', tileColor: null, removeImage: true);
      expect(h.container.read(customButtonsProvider).value!.single.imagePath, '');
      expect(h.buttons.deletedImages, [path]);
    });
  });

  test('deleting a word clears its hidden flag and any picked picture',
      () async {
    final id = await h.notifier.addButton(
        boardId: 'board_food', row: 1, col: 1, label: 'X');
    final keep = await h.notifier.addButton(
        boardId: 'board_food', row: 1, col: 0, label: 'Keep');
    await h.container
        .read(hiddenTilesProvider.notifier)
        .setHiddenBulk('board_food', [id, keep], true);
    await h.container
        .read(iconOverridesProvider.notifier)
        .setImage('board_food', id, File('p.png'));
    await h.notifier.remove(id);
    expect(h.hidden.h.forBoard('board_food'), {keep});
    expect(h.icons.m.containsKey(IconOverrideStore.key('board_food', id)),
        isFalse);
  });

  test('deleting a plain word also deletes its recorded voice and its pin',
      () async {
    final id = await h.notifier.addButton(
        boardId: 'board_food', row: 1, col: 1, label: 'X');
    await h.container.read(customVoiceProvider.notifier).save(id, File('v'));
    await h.container.read(favouritesProvider.notifier).pin('board_food', id);
    final back = await h.notifier.remove(id);
    expect(back, isNull);
    expect(h.voices.m, isEmpty);
    expect(h.favs.pinsList, isEmpty);
  });
}
