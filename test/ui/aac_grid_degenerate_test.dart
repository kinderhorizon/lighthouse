/// Regression for the grid aspect-ratio guard (review finding #11).
///
/// A transient layout pass can hand AACGrid a zero/negative available extent
/// (e.g. mid-animation or inside a collapsing parent), which makes the computed
/// childAspectRatio non-finite or <= 0. Flutter asserts childAspectRatio > 0,
/// so without the clamp the frame throws. The grid must instead fall back to a
/// square for that pass and render without error.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/aac_grid.dart';

AACButton _btn(String id, int col) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: 0, col: col),
      category: 'needs',
      baseWeight: 0.5,
      iconUri: '',
      voiceOut: id,
    );

AACBoard _board() => AACBoard(
      boardId: 'test',
      boardName: 'Test',
      schemaVersion: '1.0',
      gridDimensions: (rows: 1, cols: 2),
      colorKey: const {'needs': '#FFCC00'},
      buttons: [_btn('a', 0), _btn('b', 1)],
    );

Widget _host(double height) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: height,
            child: AACGrid(
              board: _board(),
              glow: const {},
              glowStyle: GlowStyle.halo,
              onButtonTap: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a zero-height constraint does not throw (aspect guard)',
      (tester) async {
    await tester.pumpWidget(_host(0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(AACGrid), findsOneWidget);
  });

  testWidgets('a normal constraint still lays out both tiles', (tester) async {
    await tester.pumpWidget(_host(200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
  });
}
