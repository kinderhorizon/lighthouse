/// Pure drag-reorder math (ADR 0019): insertion among non-folder slots,
/// move-to-empty, and the folder move-lock.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/edit/board_edit_screen.dart';

AACButton _word(String id, int row, int col) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: 'food',
      baseWeight: 0.5,
      iconUri: '',
    );

AACButton _folder(String id, int row, int col) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.folder,
      position: (row: row, col: col),
      category: 'food_nav',
      baseWeight: 0.5,
      iconUri: '',
      linkId: 'board_food',
    );

AACBoard _board(List<AACButton> buttons) => AACBoard(
      schemaVersion: '1.0',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 2, cols: 2),
      colorKey: const {'food': '#FFD9A6', 'food_nav': '#FFD9A6'},
      buttons: buttons,
    );

void main() {
  test('dropping a word onto another word inserts it (words shift)', () {
    // a(0,0) b(0,1) c(1,0) folder(1,1). Drop b onto a.
    final board = _board([
      _word('a', 0, 0),
      _word('b', 0, 1),
      _word('c', 1, 0),
      _folder('f', 1, 1),
    ]);
    final b = board.buttons.firstWhere((x) => x.id == 'b');
    final changed = computeReorder(board, b, (row: 0, col: 0));
    expect(changed['b'], (row: 0, col: 0));
    expect(changed['a'], (row: 0, col: 1));
    // c and the folder are unchanged.
    expect(changed.containsKey('c'), isFalse);
    expect(changed.containsKey('f'), isFalse);
  });

  test('dropping a word onto an empty slot moves it there', () {
    // a(0,0) b(0,1) folder(1,1); (1,0) empty.
    final board = _board([
      _word('a', 0, 0),
      _word('b', 0, 1),
      _folder('f', 1, 1),
    ]);
    final a = board.buttons.firstWhere((x) => x.id == 'a');
    final changed = computeReorder(board, a, (row: 1, col: 0));
    expect(changed, {'a': (row: 1, col: 0)});
  });

  test('dropping onto a folder slot is a no-op (folders are move-locked)', () {
    final board = _board([
      _word('a', 0, 0),
      _word('b', 0, 1),
      _folder('f', 1, 1),
    ]);
    final a = board.buttons.firstWhere((x) => x.id == 'a');
    expect(computeReorder(board, a, (row: 1, col: 1)), isEmpty);
  });

  test('dragging a folder is a no-op', () {
    final board = _board([
      _word('a', 0, 0),
      _folder('f', 1, 1),
    ]);
    final f = board.buttons.firstWhere((x) => x.id == 'f');
    expect(computeReorder(board, f, (row: 0, col: 0)), isEmpty);
  });

  test('dropping a word onto itself is a no-op', () {
    final board = _board([_word('a', 0, 0), _word('b', 0, 1)]);
    final a = board.buttons.firstWhere((x) => x.id == 'a');
    expect(computeReorder(board, a, (row: 0, col: 0)), isEmpty);
  });
}
