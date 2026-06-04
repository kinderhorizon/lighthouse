/// On-device verification of the ADR 0006 hitbox tap-target expansion.
///
/// The host widget test (test/ui/aac_grid_hitbox_test.dart) already
/// measures the geometry against the real Flutter layout engine. This
/// runs the SAME geometric assertions on the device binary itself, to
/// satisfy the reviewer's explicit ask: "verify on a real device that
/// the InkWell behavior matches our geometric intent." Layout math is
/// platform-independent, but this removes any host-vs-device doubt and
/// exercises the actual on-device render tree.
///
/// Run via `flutter test integration_test/ -d <device>`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/aac_button_tile.dart';
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
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: 200,
          child: AACGrid(
            board: _twoButtonBoard(),
            glow: glow,
            glowStyle: GlowStyle.halo,
            hitboxMagnitude: magnitude,
            onButtonTap: (_) {},
          ),
        ),
      ),
    ),
  );
}

Rect _tileRect(WidgetTester tester, String label) => tester.getRect(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(AACButtonTile),
      ),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('on-device: glowing tile InkWell grows into the gap',
      (tester) async {
    await tester.pumpWidget(
      _host(
        glow: const {'a': GlowLevel.gold},
        magnitude: HitboxMagnitude.maximum,
      ),
    );
    await tester.pump();

    final glowing = _tileRect(tester, 'a');
    final plain = _tileRect(tester, 'b');

    final expansion = HitboxExpansion.perSideExpansion(
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      magnitude: HitboxMagnitude.maximum,
    );
    // The InkWell (which fills the tile) is larger by 2 * perSide on
    // each axis when glowing.
    expect(glowing.width, closeTo(plain.width + 2 * expansion, 0.5));
    expect(glowing.height, closeTo(plain.height + 2 * expansion, 0.5));
  });

  testWidgets('on-device: two adjacent Maximum tiles never overlap',
      (tester) async {
    await tester.pumpWidget(
      _host(
        glow: const {'a': GlowLevel.gold, 'b': GlowLevel.gold},
        magnitude: HitboxMagnitude.maximum,
      ),
    );
    await tester.pump();

    final aRect = _tileRect(tester, 'a');
    final bRect = _tileRect(tester, 'b');
    // a is left, b is right. Their tap rects may meet but a.right must
    // not pass b.left (ADR 0006 / ADR 0003 invariant).
    expect(aRect.right, lessThanOrEqualTo(bRect.left + 0.5));
  });

  testWidgets('on-device: no glow leaves tiles equal-sized', (tester) async {
    await tester.pumpWidget(
      _host(glow: const {}, magnitude: HitboxMagnitude.maximum),
    );
    await tester.pump();
    expect(_tileRect(tester, 'a').size, _tileRect(tester, 'b').size);
  });
}
