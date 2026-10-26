/// Parent-made tiles (ADR 0022): colour, categories, replacing a built-in
/// word. Pure model logic: parsing, the overlay, the layout rule, and the
/// cascade helper.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/edit/board_edit_screen.dart' show computeReorder;

AACButton _word(String id, int row, int col, {String category = 'food'}) =>
    AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: category,
      baseWeight: 0.5,
      iconUri: '',
      voiceOut: id,
    );

AACButton _folder(String id, int row, int col, String link) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.folder,
      position: (row: row, col: col),
      category: 'food_nav',
      baseWeight: 0.5,
      iconUri: '',
      linkId: link,
    );

/// A FULL 2x2 board: three words and a folder.
AACBoard _full() => AACBoard(
      schemaVersion: '1.3',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 2, cols: 2),
      colorKey: const {'food': '#FFD9A6', 'food_nav': '#FFD9A6'},
      buttons: [
        _word('want', 0, 0),
        _word('eat', 0, 1),
        _word('drink', 1, 0),
        _folder('fld_food', 1, 1, 'board_food'),
      ],
    );

CustomButton _custom(
  String id, {
  String boardId = 'core_main',
  int row = 0,
  int col = 0,
  TileColor? color,
  String? replaces,
  String? link,
}) =>
    CustomButton(
      id: id,
      boardId: boardId,
      row: row,
      col: col,
      label: id,
      voiceOut: id,
      imagePath: '',
      tileColor: color,
      replacesId: replaces,
      linkId: link,
    );

void main() {
  group('TileColor', () {
    test('fromHex accepts the six palette fills, any case, # optional', () {
      expect(TileColor.fromHex('#C2FFC2'), TileColor.green);
      expect(TileColor.fromHex('#c2ffc2'), TileColor.green);
      expect(TileColor.fromHex('C2FFC2'), TileColor.green);
      expect(TileColor.fromHex(' #FFFFA6 '), TileColor.yellow);
      for (final c in TileColor.values) {
        expect(TileColor.fromHex(c.hex), c);
      }
    });

    test('fromHex rejects anything outside the palette', () {
      expect(TileColor.fromHex('#000000'), isNull);
      expect(TileColor.fromHex('#FFFFFF'), isNull);
      expect(TileColor.fromHex(''), isNull);
      expect(TileColor.fromHex('green'), isNull);
      expect(TileColor.fromHex(null), isNull);
      expect(TileColor.fromHex(42), isNull);
    });

    test('soleColorOf: one colour across every category, else null', () {
      expect(TileColor.soleColorOf(const {'food': '#FFD9A6'}), TileColor.orange);
      expect(
          TileColor.soleColorOf(const {'food': '#FFD9A6', 'places': '#ffd9a6'}),
          TileColor.orange);
      // Home mixes colours.
      expect(TileColor.soleColorOf(const {'verb': '#C2FFC2', 'food': '#FFD9A6'}),
          isNull);
      // A colour outside the palette never becomes the default.
      expect(TileColor.soleColorOf(const {'x': '#123456'}), isNull);
      expect(TileColor.soleColorOf(const {}), isNull);
    });
  });

  group('AACButton tile_color', () {
    test('round-trips, and is omitted when unset', () {
      final b = AACButton.fromJson({
        'id': 'x',
        'label': 'x',
        'type': 'word',
        'position': {'row': 0, 'col': 0},
        'tile_color': '#a6d9ff',
      });
      expect(b.tileColor, TileColor.blue);
      expect(b.toJson()['tile_color'], '#A6D9FF');
      expect(AACButton.fromJson(b.toJson()).tileColor, TileColor.blue);

      final plain = _word('y', 0, 0);
      expect(plain.toJson().containsKey('tile_color'), isFalse);
    });

    test('an unknown or crafted value colours by category instead of failing',
        () {
      final b = AACButton.fromJson({
        'id': 'x',
        'label': 'x',
        'type': 'word',
        'position': {'row': 0, 'col': 0},
        'tile_color': '#000000',
      });
      expect(b.tileColor, isNull);
    });

    test('withPosition and withIconUri keep the colour', () {
      const b = AACButton(
        id: 'x',
        label: 'x',
        labelByLocale: {},
        type: AACButtonType.word,
        position: (row: 0, col: 0),
        category: 'custom',
        baseWeight: 0.5,
        iconUri: '',
        tileColor: TileColor.pink,
      );
      expect(b.withPosition((row: 1, col: 1)).tileColor, TileColor.pink);
      expect(b.withIconUri('assets/a.png').tileColor, TileColor.pink);
    });
  });

  group('CustomButton', () {
    test('colour, replacement and category link round-trip', () {
      final b = _custom('c1',
          color: TileColor.purple, replaces: 'want', link: 'cat_3');
      final json = b.toJson();
      expect(json['tile_color'], '#E6A6FF');
      expect(json['replaces_id'], 'want');
      expect(json['link_id'], 'cat_3');
      final back = CustomButton.fromJson(json);
      expect(back.tileColor, TileColor.purple);
      expect(back.replacesId, 'want');
      expect(back.linkId, 'cat_3');
      expect(back.isCategory, isTrue);
    });

    test('an older entry without the new fields loads as a plain grey word',
        () {
      final back = CustomButton.fromJson({
        'id': 'c1',
        'board_id': 'core_main',
        'row': 0,
        'col': 0,
        'label': 'Cup',
        'voice_out': 'cup',
        'image_path': '',
      });
      expect(back.tileColor, isNull);
      expect(back.replacesId, isNull);
      expect(back.linkId, isNull);
      expect(back.isCategory, isFalse);
      // And it writes nothing new back.
      expect(back.toJson().keys,
          isNot(contains(anyOf('tile_color', 'replaces_id', 'link_id'))));
    });

    test('a tampered page id never becomes a link (used as a board id)', () {
      for (final bad in ['../x', 'a/b', '', 'cat 1', 'x' * 65]) {
        final back = CustomButton.fromJson({
          'id': 'c1',
          'board_id': 'core_main',
          'row': 0,
          'col': 0,
          'label': 'x',
          'link_id': bad,
        });
        expect(back.linkId, isNull, reason: 'link_id "$bad"');
      }
    });

    test('an empty replaces_id is ignored', () {
      final back = CustomButton.fromJson({
        'id': 'c1',
        'board_id': 'core_main',
        'row': 0,
        'col': 0,
        'label': 'x',
        'replaces_id': '',
      });
      expect(back.replacesId, isNull);
    });

    test('a word becomes a speaking word; a category becomes a silent folder',
        () {
      final word = _custom('w', color: TileColor.green).toAacButton();
      expect(word.type, AACButtonType.word);
      expect(word.voiceOut, 'w');
      expect(word.tileColor, TileColor.green);
      expect(word.category, kCustomCategory);

      final cat = _custom('c', color: TileColor.yellow, link: 'cat_0')
          .toAacButton();
      expect(cat.type, AACButtonType.folder);
      expect(cat.linkId, 'cat_0');
      expect(cat.voiceOut, isNull);
      expect(cat.tileColor, TileColor.yellow);
      expect(cat.category, kCustomCategory);
    });

    test('withTileColor sets and clears; withImagePath keeps everything else',
        () {
      final b = _custom('c', color: TileColor.green, replaces: 'want');
      expect(b.withTileColor(null).tileColor, isNull);
      expect(b.withTileColor(TileColor.blue).tileColor, TileColor.blue);
      final moved = b.withImagePath('/x.png');
      expect(moved.imagePath, '/x.png');
      expect(moved.tileColor, TileColor.green);
      expect(moved.replacesId, 'want');
      expect(moved.id, 'c');
    });
  });

  group('category pages', () {
    test('categoryBoardFor builds a blank 6x8 page named after the folder', () {
      final page = categoryBoardFor(_custom('School', link: 'cat_2'));
      expect(page.boardId, 'cat_2');
      expect(page.boardName, 'School');
      expect(page.gridDimensions, kCategoryGrid);
      expect(page.buttons, isEmpty);
      expect(page.emptySlots().length, 48);
    });

    test('categoryBoardById finds only pages a folder opens', () {
      final customs = [_custom('School', link: 'cat_2'), _custom('w')];
      expect(categoryBoardById('cat_2', customs)?.boardName, 'School');
      expect(categoryBoardById('cat_9', customs), isNull);
      expect(categoryBoardById('core_main', customs), isNull);
    });

    test('a new button starts in its page colour', () {
      final customs = [
        _custom('School', link: 'cat_2', color: TileColor.green),
        _custom('Plain', link: 'cat_3'),
      ];
      expect(defaultTileColorFor(categoryBoardById('cat_2', customs)!, customs),
          TileColor.green);
      // A grey category starts its words grey.
      expect(defaultTileColorFor(categoryBoardById('cat_3', customs)!, customs),
          isNull);
      // A bundled single-colour board: its group colour.
      final food = AACBoard(
        schemaVersion: '1.3',
        boardId: 'board_food',
        boardName: 'Food',
        gridDimensions: (rows: 1, cols: 1),
        colorKey: const {'food': '#FFD9A6'},
        buttons: const [],
      );
      expect(defaultTileColorFor(food, customs), TileColor.orange);
      // Home mixes colours: grey.
      final home = AACBoard(
        schemaVersion: '1.3',
        boardId: 'core_main',
        boardName: 'Home',
        gridDimensions: (rows: 1, cols: 1),
        colorKey: const {'verb': '#C2FFC2', 'food': '#FFD9A6'},
        buttons: const [],
      );
      expect(defaultTileColorFor(home, customs), isNull);
    });

    test('customSubtree collects a category, its page and nested categories',
        () {
      final customs = [
        _custom('school', link: 'cat_0'),
        _custom('pencil', boardId: 'cat_0'),
        _custom('art', boardId: 'cat_0', link: 'cat_1'),
        _custom('paint', boardId: 'cat_1'),
        _custom('home_word'),
        _custom('other', link: 'cat_5'),
        _custom('other_word', boardId: 'cat_5'),
      ];
      final t = customSubtree(['school'], customs);
      expect(t.buttonIds, {'school', 'pencil', 'art', 'paint'});
      expect(t.boardIds, {'cat_0', 'cat_1'});
      // A word has no page.
      final w = customSubtree(['home_word'], customs);
      expect(w.buttonIds, {'home_word'});
      expect(w.boardIds, isEmpty);
    });

    test('customSubtree terminates on a malformed loop', () {
      final customs = [
        _custom('a', link: 'cat_0'),
        _custom('b', boardId: 'cat_0', link: 'cat_1'),
        _custom('c', boardId: 'cat_1', link: 'cat_0'),
      ];
      final t = customSubtree(['a'], customs);
      expect(t.buttonIds, {'a', 'b', 'c'});
      expect(t.boardIds, {'cat_0', 'cat_1'});
    });
  });

  group('replacing a built-in word', () {
    test('the new button takes the word\'s slot; the word is set aside', () {
      final out = applyCustomButtons(
          _full(), [_custom('pizza', row: 0, col: 1, replaces: 'eat')]);
      expect(out.buttonAt((row: 0, col: 1))?.id, 'pizza');
      expect(out.buttons.any((b) => b.id == 'eat'), isFalse);
      // Nothing else moved.
      expect(out.buttonAt((row: 0, col: 0))?.id, 'want');
      expect(out.buttonAt((row: 1, col: 0))?.id, 'drink');
      expect(out.buttonAt((row: 1, col: 1))?.id, 'fld_food');
    });

    test('it follows the word even if the stored slot is stale', () {
      // Stored at (0,0) but replaces "drink" at (1,0).
      final out = applyCustomButtons(
          _full(), [_custom('juice', row: 0, col: 0, replaces: 'drink')]);
      expect(out.buttonAt((row: 1, col: 0))?.id, 'juice');
      expect(out.buttonAt((row: 0, col: 0))?.id, 'want');
    });

    test('without the replacement the word is simply back', () {
      expect(applyCustomButtons(_full(), const []).buttonAt((row: 0, col: 1))?.id,
          'eat');
    });

    test('a folder is never replaced (it can be the only way into a page)', () {
      final out = applyCustomButtons(
          _full(), [_custom('x', row: 1, col: 1, replaces: 'fld_food')]);
      expect(out.buttonAt((row: 1, col: 1))?.id, 'fld_food');
      // The board is full, so the new button cannot appear anywhere.
      expect(out.buttons.any((b) => b.id == 'x'), isFalse);
    });

    test('a word a content update removed: placed like any custom button', () {
      final board = _full().copyWithButtons(
          _full().buttons.where((b) => b.id != 'eat').toList());
      final out = applyCustomButtons(
          board, [_custom('pizza', row: 0, col: 1, replaces: 'eat')]);
      expect(out.buttonAt((row: 0, col: 1))?.id, 'pizza');
    });

    test('a second replacement of the same word never evicts anything', () {
      final out = applyCustomButtons(_full(), [
        _custom('pizza', row: 0, col: 1, replaces: 'eat'),
        _custom('pasta', row: 0, col: 1, replaces: 'eat'),
      ]);
      expect(out.buttonAt((row: 0, col: 1))?.id, 'pizza');
      expect(out.buttons.map((b) => b.id),
          containsAll(['want', 'drink', 'fld_food', 'pizza']));
      expect(out.buttons.any((b) => b.id == 'pasta'), isFalse);
    });

    test('an ordinary custom button never lands on a replacement', () {
      final board = AACBoard(
        schemaVersion: '1.3',
        boardId: 'core_main',
        boardName: 'Home',
        gridDimensions: (rows: 1, cols: 3),
        colorKey: const {},
        buttons: [_word('want', 0, 0), _word('eat', 0, 1)],
      );
      final out = applyCustomButtons(board, [
        _custom('plain', row: 0, col: 1), // listed first, collides with "eat"
        _custom('pizza', row: 0, col: 1, replaces: 'eat'),
      ]);
      expect(out.buttonAt((row: 0, col: 1))?.id, 'pizza');
      expect(out.buttonAt((row: 0, col: 2))?.id, 'plain');
      expect(out.buttonAt((row: 0, col: 0))?.id, 'want');
    });
  });

  group('layout rule for parent-made folders', () {
    test('isBuiltInFolder: built-in folders only', () {
      expect(isBuiltInFolder(_folder('f', 0, 0, 'board_food')), isTrue);
      expect(isBuiltInFolder(_custom('c', link: 'cat_0').toAacButton()), isFalse);
      expect(isBuiltInFolder(_word('w', 0, 0)), isFalse);
    });

    test('a parent-made category honours its override; a built-in folder never',
        () {
      final board = AACBoard(
        schemaVersion: '1.3',
        boardId: 'b',
        boardName: 'B',
        gridDimensions: (rows: 1, cols: 4),
        colorKey: const {},
        buttons: [
          _folder('fld', 0, 0, 'board_food'),
          _custom('cat', boardId: 'b', row: 0, col: 1, link: 'cat_0')
              .toAacButton(),
        ],
      );
      final layout = const BoardLayout.empty().withPositions('b', {
        'fld': (row: 0, col: 3),
        'cat': (row: 0, col: 2),
      });
      final out = applyLayout(board, layout);
      expect(out.buttonAt((row: 0, col: 0))?.id, 'fld');
      expect(out.buttonAt((row: 0, col: 2))?.id, 'cat');
    });

    test('drag reorder: a parent-made category moves, a built-in folder does not',
        () {
      final cat = _custom('cat', boardId: 'b', row: 0, col: 1, link: 'cat_0')
          .toAacButton();
      final fld = _folder('fld', 0, 0, 'board_food');
      final board = AACBoard(
        schemaVersion: '1.3',
        boardId: 'b',
        boardName: 'B',
        gridDimensions: (rows: 1, cols: 4),
        colorKey: const {},
        buttons: [fld, cat, _word('w', 0, 2)],
      );
      expect(computeReorder(board, cat, (row: 0, col: 3)),
          {'cat': (row: 0, col: 3)});
      expect(computeReorder(board, fld, (row: 0, col: 3)), isEmpty);
      // Dropping a word onto a built-in folder is still a no-op.
      expect(computeReorder(board, board.buttons[2], (row: 0, col: 0)), isEmpty);
      // Dropping a word onto a parent-made category reorders.
      expect(computeReorder(board, board.buttons[2], (row: 0, col: 1)),
          {'w': (row: 0, col: 1), 'cat': (row: 0, col: 2)});
    });
  });
}
