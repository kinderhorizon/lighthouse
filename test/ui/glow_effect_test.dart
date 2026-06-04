import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/ui/glow_effect.dart';

Widget _frame(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('GlowEffect', () {
    testWidgets('none level: returns child unchanged', (tester) async {
      const key = ValueKey('tile');
      await tester.pumpWidget(_frame(
        const GlowEffect(
          level: GlowLevel.none,
          style: GlowStyle.halo,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      expect(find.byKey(key), findsOneWidget);
      expect(find.byKey(const ValueKey('glow.halo')), findsNothing);
      expect(find.byKey(const ValueKey('glow.ring')), findsNothing);
      expect(find.byKey(const ValueKey('glow.lift')), findsNothing);
      expect(find.byKey(const ValueKey('glow.dot')), findsNothing);
    });

    testWidgets('off style: returns child unchanged even at gold',
        (tester) async {
      const key = ValueKey('tile');
      await tester.pumpWidget(_frame(
        const GlowEffect(
          level: GlowLevel.gold,
          style: GlowStyle.off,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      expect(find.byKey(key), findsOneWidget);
      expect(find.byKey(const ValueKey('glow.halo')), findsNothing);
    });

    testWidgets('halo style at gold animates', (tester) async {
      const key = ValueKey('tile');
      await tester.pumpWidget(_frame(
        const GlowEffect(
          level: GlowLevel.gold,
          style: GlowStyle.halo,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      expect(find.byKey(key), findsOneWidget);
      expect(find.byKey(const ValueKey('glow.halo')), findsOneWidget);
      // Pump across the pulse period to ensure no frames throw.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));
    });

    testWidgets('halo renders (static) when reduced motion is on',
        (tester) async {
      const key = ValueKey('tile');
      await tester.pumpWidget(_frame(
        disableAnimations: true,
        const GlowEffect(
          level: GlowLevel.gold,
          style: GlowStyle.halo,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      expect(find.byKey(key), findsOneWidget);
      expect(find.byKey(const ValueKey('glow.halo')), findsOneWidget);
    });

    testWidgets('ring style renders the ring overlay', (tester) async {
      const key = ValueKey('tile');
      await tester.pumpWidget(_frame(
        const GlowEffect(
          level: GlowLevel.shimmer,
          style: GlowStyle.ring,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      expect(find.byKey(key), findsOneWidget);
      expect(find.byKey(const ValueKey('glow.ring')), findsOneWidget);
    });

    testWidgets('lift style renders the lift wrapper', (tester) async {
      const key = ValueKey('tile');
      await tester.pumpWidget(_frame(
        const GlowEffect(
          level: GlowLevel.gold,
          style: GlowStyle.lift,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      expect(find.byKey(key), findsOneWidget);
      expect(find.byKey(const ValueKey('glow.lift')), findsOneWidget);
    });

    testWidgets('dot style renders the corner dot', (tester) async {
      const key = ValueKey('tile');
      await tester.pumpWidget(_frame(
        const GlowEffect(
          level: GlowLevel.gold,
          style: GlowStyle.dot,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      expect(find.byKey(key), findsOneWidget);
      expect(find.byKey(const ValueKey('glow.dot')), findsOneWidget);
    });

    testWidgets('does not introduce a layout shift around the child',
        (tester) async {
      const key = ValueKey('tile');
      await tester.pumpWidget(_frame(
        const GlowEffect(
          level: GlowLevel.none,
          style: GlowStyle.halo,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      final sizeBefore = tester.getSize(find.byKey(key));

      await tester.pumpWidget(_frame(
        const GlowEffect(
          level: GlowLevel.gold,
          style: GlowStyle.halo,
          child: SizedBox(key: key, width: 40, height: 40),
        ),
      ));
      final sizeAfter = tester.getSize(find.byKey(key));
      expect(sizeAfter, sizeBefore,
          reason: 'Glow is decorative and must not affect layout');
    });
  });
}
