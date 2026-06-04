/// Verifies the ADR 0006 hitbox tap-target expansion is wired into the
/// grid: a glowing tile's Material/InkWell physically grows into the gap
/// (larger rendered size), while non-glowing neighbors are unmoved and
/// the invariant (no overlap) holds.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/aac_grid.dart';
import 'package:lighthouse/ui/aac_button_tile.dart';

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

AACBoard _twoButtonBoard() => AACBoard(
      boardId: 'test',
      boardName: 'Test',
      schemaVersion: '1.0',
      gridDimensions: (rows: 1, cols: 2),
      colorKey: const {'needs': '#FFCC00'},
      buttons: [_btn('a', 0), _btn('b', 1)],
    );

Widget _host({
  required Map<String, GlowLevel> glow,
  required HitboxMagnitude magnitude,
  GlowStyle style = GlowStyle.dot, // no transform/timer; measures pure hitbox
  double crossSpacing = 8,
  double mainSpacing = 8,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        // Fixed box so cell math is deterministic.
        child: SizedBox(
          width: 400,
          height: 200,
          child: AACGrid(
            board: _twoButtonBoard(),
            glow: glow,
            glowStyle: style,
            hitboxMagnitude: magnitude,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
            onButtonTap: (_) {},
          ),
        ),
      ),
    ),
  );
}

Size _tileSize(WidgetTester tester, String label) {
  final finder = find.ancestor(
    of: find.text(label),
    matching: find.byType(AACButtonTile),
  );
  return tester.getSize(finder);
}

void main() {
  testWidgets('no glow: both tiles are the same size', (tester) async {
    await tester.pumpWidget(
      _host(glow: const {}, magnitude: HitboxMagnitude.maximum),
    );
    await tester.pump();
    final a = _tileSize(tester, 'a');
    final b = _tileSize(tester, 'b');
    expect(a, b);
  });

  testWidgets('glowing tile grows by 2 * perSideExpansion vs its neighbor',
      (tester) async {
    await tester.pumpWidget(
      _host(glow: const {'a': GlowLevel.gold}, magnitude: HitboxMagnitude.maximum),
    );
    await tester.pump();

    final glowing = _tileSize(tester, 'a');
    final plain = _tileSize(tester, 'b');

    // Maximum on an 8px gap: perSide = min(8,8)/2 * 1.0 = 4. The glowing
    // tile reclaims its 4px internal padding on each side -> +8 in width
    // and +8 in height.
    final expansion = HitboxExpansion.perSideExpansion(
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      magnitude: HitboxMagnitude.maximum,
    );
    expect(glowing.width, closeTo(plain.width + 2 * expansion, 0.5));
    expect(glowing.height, closeTo(plain.height + 2 * expansion, 0.5));
  });

  testWidgets('Subtle expands less than Maximum', (tester) async {
    await tester.pumpWidget(
      _host(glow: const {'a': GlowLevel.gold}, magnitude: HitboxMagnitude.subtle),
    );
    await tester.pump();
    final subtleW = _tileSize(tester, 'a').width;

    await tester.pumpWidget(
      _host(glow: const {'a': GlowLevel.gold}, magnitude: HitboxMagnitude.maximum),
    );
    await tester.pump();
    final maxW = _tileSize(tester, 'a').width;

    expect(subtleW, lessThan(maxW));
  });

  testWidgets('glow OFF: a "glowing" tile does NOT grow (no hint of any kind)',
      (tester) async {
    // clinical review: when the glow style is Off the board must give NO next-word
    // hint, glow or otherwise. The bug was that a predicted tile still expanded
    // its hitbox (read as a "slight lift") even with glow off. The grid now
    // forces every tile to the none level when the style does not show glow.
    await tester.pumpWidget(_host(
      glow: const {'a': GlowLevel.gold},
      magnitude: HitboxMagnitude.maximum,
      style: GlowStyle.off,
    ));
    await tester.pump();
    expect(_tileSize(tester, 'a'), _tileSize(tester, 'b'),
        reason: 'glow off must not lift/expand a suggested tile');
  });

  testWidgets('None magnitude: glow does not change tile size', (tester) async {
    await tester.pumpWidget(
      _host(glow: const {'a': GlowLevel.gold}, magnitude: HitboxMagnitude.none),
    );
    await tester.pump();
    final glowing = _tileSize(tester, 'a');
    final plain = _tileSize(tester, 'b');
    expect(glowing, plain);
  });

  testWidgets('two adjacent glowing tiles at Maximum do not overlap',
      (tester) async {
    await tester.pumpWidget(
      _host(
        glow: const {'a': GlowLevel.gold, 'b': GlowLevel.gold},
        magnitude: HitboxMagnitude.maximum,
      ),
    );
    await tester.pump();

    final aRect = tester.getRect(
      find.ancestor(
        of: find.text('a'),
        matching: find.byType(AACButtonTile),
      ),
    );
    final bRect = tester.getRect(
      find.ancestor(
        of: find.text('b'),
        matching: find.byType(AACButtonTile),
      ),
    );
    // a is the left cell, b the right. Their tap rects may touch but the
    // right edge of a must not pass the left edge of b (the ADR 0006
    // invariant: combined expansion equals the gap, never exceeds it).
    expect(aRect.right, lessThanOrEqualTo(bRect.left + 0.5));
  });
}
