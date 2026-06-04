/// Custom button model + overlay (ADR 0012).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';

AACBoard _board(List<Map<String, dynamic>> buttons) => AACBoard.fromJson({
      'schema_version': '1.0',
      'board_id': 'board_food',
      'grid_dimensions': [2, 2],
      'color_key': {},
      'buttons': buttons,
    });

Map<String, dynamic> _btn(String id, int row, int col) => {
      'id': id,
      'label': id,
      'type': 'word',
      'voice_out': id,
      'position': {'row': row, 'col': col},
      'category': 'food',
    };

void main() {
  test('toJson/fromJson round-trips the stable id (ADR 0014)', () {
    const b = CustomButton(
      id: 'custom_board_food_5',
      boardId: 'board_food',
      row: 1,
      col: 2,
      label: 'Sippy cup',
      voiceOut: 'sippy cup',
      imagePath: '/data/custom_images/x.png',
    );
    final back = CustomButton.fromJson(b.toJson());
    expect(back.boardId, 'board_food');
    expect(back.row, 1);
    expect(back.col, 2);
    expect(back.label, 'Sippy cup');
    expect(back.voiceOut, 'sippy cup');
    expect(back.imagePath, '/data/custom_images/x.png');
    // The stable id survives a move (row/col would change, id must not).
    expect(back.id, 'custom_board_food_5');
  });

  test('fromJson migrates a legacy entry (no stored id) to a derived id', () {
    // ADR 0014: a file written before stable ids has no "id" field; the old
    // slot-derived id is reconstructed once so bandit posteriors keyed on it
    // are preserved.
    final back = CustomButton.fromJson({
      'board_id': 'board_food',
      'row': 1,
      'col': 2,
      'label': 'Sippy cup',
      'voice_out': 'sippy cup',
      'image_path': 'x.png',
    });
    expect(back.id, 'custom_board_food_1_2');
  });

  test('overlay places a custom button into an empty slot', () {
    final base = _board([_btn('btn_food_apple', 0, 0)]);
    const custom = CustomButton(
      id: 'custom_board_food_0',
      boardId: 'board_food',
      row: 0,
      col: 1,
      label: 'Sippy cup',
      voiceOut: 'sippy cup',
      imagePath: '/img/cup.png',
    );
    final merged = applyCustomButtons(base, [custom]);
    expect(merged.buttons, hasLength(2));
    final placed = merged.buttonAt((row: 0, col: 1));
    expect(placed?.label, 'Sippy cup');
    expect(placed?.category, kCustomCategory);
    expect(placed?.iconUri, '/img/cup.png');
    expect(placed?.type, AACButtonType.word);
  });

  test('overlay ignores custom buttons for other boards', () {
    final base = _board([_btn('btn_food_apple', 0, 0)]);
    const other = CustomButton(
      id: 'custom_board_places_0',
      boardId: 'board_places',
      row: 0,
      col: 1,
      label: 'Park',
      voiceOut: 'park',
      imagePath: '',
    );
    expect(applyCustomButtons(base, [other]).buttons, hasLength(1));
  });

  test('custom button wins on a slot collision', () {
    final base = _board([_btn('btn_food_apple', 0, 0)]);
    const custom = CustomButton(
      id: 'custom_board_food_0',
      boardId: 'board_food',
      row: 0,
      col: 0,
      label: 'Mine',
      voiceOut: 'mine',
      imagePath: '',
    );
    final merged = applyCustomButtons(base, [custom]);
    expect(merged.buttons, hasLength(1));
    expect(merged.buttonAt((row: 0, col: 0))?.label, 'Mine');
  });

  test('a custom button does NOT evict a folder on a slot collision (M6)', () {
    // Under OTA layout skew a bundled folder can shift onto a custom's target
    // slot; the folder is the only path into its sub-board, so it must win.
    final base = _board([
      {
        'id': 'fld_food',
        'label': 'Food',
        'type': 'folder',
        'position': {'row': 0, 'col': 0},
        'category': 'nav',
        'link_id': 'board_sub',
      },
    ]);
    const custom = CustomButton(
      id: 'custom_board_food_0',
      boardId: 'board_food',
      row: 0,
      col: 0,
      label: 'Mine',
      voiceOut: 'mine',
      imagePath: '',
    );
    final merged = applyCustomButtons(base, [custom]);
    final at = merged.buttonAt((row: 0, col: 0));
    expect(at?.type, AACButtonType.folder,
        reason: 'the folder (sub-board doorway) must survive the collision');
    expect(at?.linkId, 'board_sub');
  });

  test('emptySlots lists unoccupied cells row-major', () {
    final base = _board([_btn('a', 0, 0), _btn('b', 1, 1)]);
    expect(base.emptySlots(), [(row: 0, col: 1), (row: 1, col: 0)]);
    expect(base.emptySlots(limit: 1), [(row: 0, col: 1)]);
  });
}
