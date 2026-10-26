/// Hidden tiles on the reflowed grid (ADR 0019 + handoff Rule 3). Phones and
/// small tablets reflow the board into fewer columns and scroll. Hiding a tile
/// there must leave a blank cell in its place, exactly like the large-tablet
/// grid: no other tile may move, so the child's muscle memory survives a hide
/// or a show (ADR 0006).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/aac_button_tile.dart';
import 'package:lighthouse/ui/aac_grid.dart';
import 'package:lighthouse/ui/board_size_tier.dart';

AACButton _btn(String id, int row, int col) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: 'needs',
      baseWeight: 0.5,
      iconUri: '',
      voiceOut: id,
    );

/// A 2x8 board. Slots in [empty] never hold a tile (a sparse board).
AACBoard _board({Set<Position> empty = const {}}) => AACBoard(
      boardId: 'core_main',
      boardName: 'Home',
      schemaVersion: '1.0',
      gridDimensions: (rows: 2, cols: 8),
      colorKey: const {'needs': '#FFCC00'},
      buttons: [
        for (var r = 0; r < 2; r++)
          for (var c = 0; c < 8; c++)
            if (!empty.contains((row: r, col: c))) _btn('b_${r}_$c', r, c),
      ],
    );

AACBoard _hide(AACBoard board, List<String> ids) => applyHiddenTiles(
      board,
      const HiddenTiles.empty().withBulkVisibility(board.boardId, ids, true),
    );

// Drive the real surface size, as the child board screen does, and pick the
// column count from the same tier logic.
Future<void> _pump(WidgetTester tester, Size canvas, AACBoard board) async {
  tester.view.physicalSize = canvas;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final sizing = boardSizingFor(
    shortestSide: canvas.shortestSide,
    nativeColumns: board.gridDimensions.cols,
  );
  expect(sizing.scrolls, isTrue, reason: '$canvas must use the reflow grid');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AACGrid(
          board: board,
          columns: sizing.columns,
          scroll: sizing.scrolls,
          onButtonTap: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _tile(String id) => find.byWidgetPredicate(
      (w) => w is AACButtonTile && w.button.id == id,
    );

/// Top-left of every tile on screen, keyed by button id.
Map<String, Offset> _layout(WidgetTester tester) => {
      for (final t
          in tester.widgetList<AACButtonTile>(find.byType(AACButtonTile)))
        t.button.id: tester.getTopLeft(_tile(t.button.id)),
    };

void main() {
  const devices = {
    'phone': Size(390, 844),
    'small tablet': Size(800, 1280),
  };

  for (final device in devices.entries) {
    testWidgets('${device.key}: hiding tiles moves no other tile',
        (tester) async {
      await _pump(tester, device.value, _board());
      final before = _layout(tester);
      expect(before, hasLength(16));

      // A middle tile, the first tile of a row, and the very last tile.
      const hidden = ['b_0_2', 'b_1_0', 'b_1_7'];
      await _pump(tester, device.value, _hide(_board(), hidden));
      final after = _layout(tester);

      for (final id in hidden) {
        expect(_tile(id), findsNothing, reason: '$id is hidden');
      }
      expect(after, hasLength(16 - hidden.length));
      for (final e in after.entries) {
        expect(e.value, before[e.key],
            reason: '${e.key} must not move when other tiles are hidden');
      }
    });
  }

  testWidgets('a slot that never held a tile is still skipped, so boards with '
      'nothing hidden reflow as before', (tester) async {
    const phone = Size(390, 844);
    await _pump(tester, phone, _board());
    final dense = _layout(tester);

    await _pump(tester, phone, _board(empty: {(row: 0, col: 2)}));
    final sparse = _layout(tester);

    // b_0_3 closes the gap left by the empty slot.
    expect(sparse['b_0_3'], dense['b_0_2']);
  });
}
