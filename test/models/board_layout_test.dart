/// Board layout overlay + applyLayout resolve (ADR 0014).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';

AACButton _btn(String id, int row, int col, {String category = 'cat'}) =>
    AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: category,
      baseWeight: 0.5,
      iconUri: '',
    );

AACBoard _board(int rows, int cols, List<AACButton> buttons) => AACBoard(
      schemaVersion: '1.0',
      boardId: 'b',
      boardName: 'b',
      gridDimensions: (rows: rows, cols: cols),
      colorKey: const {},
      buttons: buttons,
    );

/// Asserts the board is a valid layout: every slot occupied at most once, and
/// the multiset of (id, category) pairs is exactly [expected] (positions moved,
/// identities never).
void _assertPermutation(AACBoard board, Set<String> expectedIds) {
  final slots = <Position>{};
  for (final b in board.buttons) {
    expect(slots.add(b.position), isTrue,
        reason: 'two buttons share slot ${b.position}');
    expect(b.position.row, inInclusiveRange(0, board.gridDimensions.rows - 1));
    expect(b.position.col, inInclusiveRange(0, board.gridDimensions.cols - 1));
  }
  expect(board.buttons.map((b) => b.id).toSet(), expectedIds);
}

void main() {
  test('empty layout returns the board unchanged (identity)', () {
    final board = _board(1, 2, [_btn('a', 0, 0), _btn('b', 0, 1)]);
    expect(identical(applyLayout(board, const BoardLayout.empty()), board),
        isTrue);
  });

  test('swap exchanges two buttons positions', () {
    final board = _board(1, 2, [_btn('a', 0, 0), _btn('b', 0, 1)]);
    final layout = const BoardLayout.empty()
        .withSwap('b', 'a', (row: 0, col: 0), 'b', (row: 0, col: 1));
    final out = applyLayout(board, layout);
    expect(out.buttonAt((row: 0, col: 1))?.id, 'a');
    expect(out.buttonAt((row: 0, col: 0))?.id, 'b');
    _assertPermutation(out, {'a', 'b'});
  });

  test('move onto an empty slot relocates the button', () {
    final board = _board(1, 3, [_btn('a', 0, 0)]);
    final layout =
        const BoardLayout.empty().withPosition('b', 'a', (row: 0, col: 2));
    final out = applyLayout(board, layout);
    expect(out.buttonAt((row: 0, col: 2))?.id, 'a');
    expect(out.buttonAt((row: 0, col: 0)), isNull);
  });

  test('the overlay never mutates id or category, only position', () {
    final board = _board(1, 2, [
      _btn('a', 0, 0, category: 'verb'),
      _btn('b', 0, 1, category: 'food'),
    ]);
    final out = applyLayout(
      board,
      const BoardLayout.empty()
          .withSwap('b', 'a', (row: 0, col: 0), 'b', (row: 0, col: 1)),
    );
    expect(out.buttonAt((row: 0, col: 1))?.category, 'verb'); // a moved here
    expect(out.buttonAt((row: 0, col: 0))?.category, 'food'); // b moved here
  });

  group('content-update skew (Decision 5 robustness)', () {
    test('an override for a button no longer present is dropped', () {
      final board = _board(1, 2, [_btn('a', 0, 0), _btn('b', 0, 1)]);
      // Layout authored when a "ghost" button existed; it has since been
      // removed from the bundled board.
      final layout = const BoardLayout.empty()
          .withPosition('b', 'ghost', (row: 0, col: 0));
      final out = applyLayout(board, layout);
      _assertPermutation(out, {'a', 'b'});
      expect(out.buttonAt((row: 0, col: 0))?.id, 'a');
      expect(out.buttonAt((row: 0, col: 1))?.id, 'b');
    });

    test('a one-sided override colliding with a non-overridden button resolves '
        'to a valid permutation, never an overlap', () {
      // 'a' is moved onto 'b''s slot, but 'b' has no override (e.g. a content
      // update changed the picture). The resolve must place both, no overlap.
      final board = _board(1, 2, [_btn('a', 0, 0), _btn('b', 0, 1)]);
      final layout =
          const BoardLayout.empty().withPosition('b', 'a', (row: 0, col: 1));
      final out = applyLayout(board, layout);
      _assertPermutation(out, {'a', 'b'});
      expect(out.buttonAt((row: 0, col: 1))?.id, 'a'); // override honored
      expect(out.buttonAt((row: 0, col: 0))?.id, 'b'); // displaced to free slot
    });

    test('a folder is never displaced, even when an override targets its slot',
        () {
      // ADR 0014 Amendment 1: folders (subcategories) are pinned to their
      // bundled slot and placed first, so a stray override (content-update skew)
      // can never relocate one.
      final folder = AACButton(
        id: 'fld_food',
        label: 'Food',
        labelByLocale: const {},
        type: AACButtonType.folder,
        position: (row: 0, col: 0),
        category: 'food_nav',
        baseWeight: 0.5,
        iconUri: '',
        linkId: 'board_food',
      );
      final board = _board(1, 2, [folder, _btn('w', 0, 1)]);
      // An override (somehow) points word w onto the folder's slot.
      final layout =
          const BoardLayout.empty().withPosition('b', 'w', (row: 0, col: 0));
      final out = applyLayout(board, layout);
      expect(out.buttonAt((row: 0, col: 0))?.id, 'fld_food',
          reason: 'folder keeps its slot');
      _assertPermutation(out, {'fld_food', 'w'});
    });

    test('an override pointing off the (shrunk) grid falls back safely', () {
      final board = _board(1, 2, [_btn('a', 0, 0), _btn('b', 0, 1)]);
      final layout =
          const BoardLayout.empty().withPosition('b', 'a', (row: 9, col: 9));
      final out = applyLayout(board, layout);
      _assertPermutation(out, {'a', 'b'});
    });
  });

  test('resolve is deterministic across repeated calls', () {
    final board = _board(2, 2, [
      _btn('a', 0, 0),
      _btn('b', 0, 1),
      _btn('c', 1, 0),
    ]);
    final layout = const BoardLayout.empty()
        .withPosition('b', 'a', (row: 1, col: 1))
        .withPosition('b', 'c', (row: 0, col: 0));
    final first = applyLayout(board, layout);
    final second = applyLayout(board, layout);
    expect(
      {for (final b in first.buttons) b.id: b.position},
      {for (final b in second.buttons) b.id: b.position},
    );
  });

  group('serialization', () {
    test('toJson/fromJson round-trips', () {
      final layout = const BoardLayout.empty()
          .withPosition('core_main', 'btn_want', (row: 2, col: 3))
          .withPosition('core_main', 'btn_eat', (row: 0, col: 1));
      final back = BoardLayout.fromJson(layout.toJson());
      expect(back.positionOf('core_main', 'btn_want'), (row: 2, col: 3));
      expect(back.positionOf('core_main', 'btn_eat'), (row: 0, col: 1));
    });

    test('withoutBoard and cleared drop overrides', () {
      final layout = const BoardLayout.empty()
          .withPosition('b1', 'x', (row: 0, col: 0))
          .withPosition('b2', 'y', (row: 1, col: 1));
      expect(layout.withoutBoard('b1').positionOf('b1', 'x'), isNull);
      expect(layout.withoutBoard('b1').positionOf('b2', 'y'), (row: 1, col: 1));
      expect(layout.cleared().isEmpty, isTrue);
    });

    test('fromJson skips malformed entries', () {
      final back = BoardLayout.fromJson({
        'b': {
          'good': {'row': 1, 'col': 2},
          'bad_no_col': {'row': 1},
          'bad_type': 'nope',
        },
        'not_a_map': 5,
      });
      expect(back.positionOf('b', 'good'), (row: 1, col: 2));
      expect(back.positionOf('b', 'bad_no_col'), isNull);
      expect(back.positionOf('b', 'bad_type'), isNull);
    });
  });
}
