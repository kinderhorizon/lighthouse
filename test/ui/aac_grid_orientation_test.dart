/// Orientation invariant (designer build-critical rule 2, v4): the board FILLS
/// the available space in both orientations. The 8 columns and every tile's
/// row/column never change, but the cell SHAPE adapts: portrait cells are
/// tallish, landscape cells get wider and bigger. The board must NOT letterbox
/// (a fixed-aspect FittedBox that wastes the width in landscape) and must NOT
/// hard-code a portrait aspect. This guards both failures.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/aac_grid.dart';
import 'package:lighthouse/ui/aac_button_tile.dart';

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

AACBoard _board() => AACBoard(
      boardId: 'test',
      boardName: 'Test',
      schemaVersion: '1.0',
      gridDimensions: (rows: 7, cols: 8),
      colorKey: const {'needs': '#FFCC00'},
      buttons: [
        for (var r = 0; r < 7; r++)
          for (var c = 0; c < 8; c++) _btn('b_${r}_$c', r, c),
      ],
    );

// Drive the real surface size so the board fills it (a SizedBox larger than
// the default 800x600 test surface would be clamped and defeat the point).
Future<void> _pump(WidgetTester tester, Size canvas) async {
  tester.view.physicalSize = canvas;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AACGrid(board: _board(), onButtonTap: (_) {})),
    ),
  );
  await tester.pump();
}

Rect _tileRect(WidgetTester tester) =>
    tester.getRect(find.byType(AACButtonTile).first);

void main() {
  testWidgets('portrait: cells are tallish (portrait aspect)', (tester) async {
    await _pump(tester, const Size(820, 1180));
    final r = _tileRect(tester);
    expect(r.width / r.height, lessThan(0.95),
        reason: 'portrait cells must be taller than wide');
  });

  testWidgets('landscape: cells get WIDER and fill the width (no letterbox)',
      (tester) async {
    await _pump(tester, const Size(1180, 820));
    final r = _tileRect(tester);
    // The board must fill, not letterbox: in landscape the cells reshape wide.
    expect(r.width / r.height, greaterThan(1.1),
        reason: 'landscape cells must be wider than tall (filled, not boxed)');
  });

  testWidgets('the board fills the width: landscape tiles are wider than '
      'portrait tiles', (tester) async {
    await _pump(tester, const Size(820, 1180));
    final portraitW = _tileRect(tester).width;

    await _pump(tester, const Size(1180, 820));
    final landscapeW = _tileRect(tester).width;

    expect(landscapeW, greaterThan(portraitW),
        reason: 'landscape must use the extra width (fill, not letterbox)');
  });
}
