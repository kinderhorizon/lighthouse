/// HiddenTiles + icon-override board transforms (ADR 0019).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart' show applyIconOverrides, IconOverrideStore;

AACButton _word(String id, int row, int col, {String icon = 'assets/x.png'}) =>
    AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: 'food',
      baseWeight: 0.5,
      iconUri: icon,
    );

AACBoard _board() => AACBoard(
      schemaVersion: '1.0',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 1, cols: 3),
      colorKey: const {'food': '#FFD9A6'},
      buttons: [_word('a', 0, 0), _word('b', 0, 1), _word('c', 0, 2)],
    );

void main() {
  group('HiddenTiles', () {
    test('toggle add/remove and isHidden', () {
      var h = const HiddenTiles.empty();
      expect(h.isHidden('core_main', 'a'), isFalse);
      h = h.withVisibility('core_main', 'a', true);
      expect(h.isHidden('core_main', 'a'), isTrue);
      expect(h.forBoard('core_main'), {'a'});
      h = h.withVisibility('core_main', 'a', false);
      expect(h.isHidden('core_main', 'a'), isFalse);
      expect(h.isEmpty, isTrue);
    });

    test('bulk visibility + per-board reset', () {
      var h = const HiddenTiles.empty()
          .withBulkVisibility('core_main', ['a', 'b'], true);
      expect(h.isHidden('core_main', 'a'), isTrue);
      expect(h.isHidden('core_main', 'b'), isTrue);
      h = h.withoutBoard('core_main');
      expect(h.isEmpty, isTrue);
    });

    test('json round-trips', () {
      final h = const HiddenTiles.empty()
          .withBulkVisibility('core_main', ['a', 'b'], true);
      final back = HiddenTiles.fromJson(h.toJson());
      expect(back.isHidden('core_main', 'a'), isTrue);
      expect(back.isHidden('core_main', 'b'), isTrue);
    });

    test('applyHiddenTiles drops hidden buttons (slot left empty)', () {
      final board = _board();
      final hidden =
          const HiddenTiles.empty().withVisibility('core_main', 'b', true);
      final out = applyHiddenTiles(board, hidden);
      expect(out.buttons.map((x) => x.id), ['a', 'c']);
      // a and c keep their original positions (no reflow).
      expect(out.buttonAt((row: 0, col: 0))?.id, 'a');
      expect(out.buttonAt((row: 0, col: 1)), isNull); // b's slot now empty
      expect(out.buttonAt((row: 0, col: 2))?.id, 'c');
    });

    test('applyHiddenTiles with no hides returns the same board', () {
      final board = _board();
      expect(identical(applyHiddenTiles(board, const HiddenTiles.empty()),
          board), isTrue);
    });
  });

  group('applyIconOverrides', () {
    test('repoints a button icon_uri by (board, button) key', () {
      final board = _board();
      final overrides = {
        IconOverrideStore.key('core_main', 'b'): '/data/custom/b.png',
      };
      final out = applyIconOverrides(board, overrides);
      expect(out.buttonAt((row: 0, col: 1))?.iconUri, '/data/custom/b.png');
      // Other tiles untouched; identity preserved.
      expect(out.buttonAt((row: 0, col: 0))?.iconUri, 'assets/x.png');
      expect(out.buttonAt((row: 0, col: 1))?.id, 'b');
    });

    test('no overrides returns the same board', () {
      final board = _board();
      expect(identical(applyIconOverrides(board, const {}), board), isTrue);
    });
  });
}
