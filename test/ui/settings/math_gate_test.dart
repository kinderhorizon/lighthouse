import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lighthouse/ui/ui.dart';

import '../../support/localized.dart';

void main() {
  Widget _host(VoidCallback onUnlocked) {
    return localizedApp(
      Scaffold(
        body: MathGate(
          questionSeed: (a: 5, b: 7),
          onUnlocked: onUnlocked,
        ),
      ),
    );
  }

  // The gate uses an on-screen keypad (not the platform soft keyboard, which is
  // unreliable on a tethered tablet, clinical review). Each digit key carries a
  // ValueKey('mathkey_<n>'); the submit button is ValueKey('mathgate_continue').
  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('mathkey_$d')));
      await tester.pump();
    }
  }

  testWidgets('Correct answer fires onUnlocked', (tester) async {
    var unlocked = false;
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(() => unlocked = true));
    await tester.pump();

    await tapDigits(tester, '12');
    await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
    await tester.pump();

    expect(unlocked, isTrue);
  });

  testWidgets('Wrong answer rejects with error text and stays gated',
      (tester) async {
    var unlocked = false;
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(() => unlocked = true));
    await tester.pump();

    await tapDigits(tester, '11');
    await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
    await tester.pump();

    expect(unlocked, isFalse);
    expect(find.text('Not quite. Try again.'), findsOneWidget);
  });

  testWidgets('Empty submission cannot unlock (submit is disabled)',
      (tester) async {
    var unlocked = false;
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(() => unlocked = true));
    await tester.pump();

    // With no digits entered the submit button is disabled; tapping is a no-op.
    await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
    await tester.pump();

    expect(unlocked, isFalse);
  });

  testWidgets('Backspace corrects a mistyped digit', (tester) async {
    var unlocked = false;
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(() => unlocked = true));
    await tester.pump();

    // Type 19, backspace the 9, type 2 -> 12 (correct for 5 + 7).
    await tapDigits(tester, '19');
    await tester.tap(find.byKey(const ValueKey('mathkey_backspace')));
    await tester.pump();
    await tapDigits(tester, '2');
    await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
    await tester.pump();

    expect(unlocked, isTrue);
  });

  testWidgets('Renders and unlocks under Arabic locale (RTL, localized button)',
      (tester) async {
    var unlocked = false;
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: MathGate(
          questionSeed: (a: 5, b: 7),
          onUnlocked: () => unlocked = true,
        ),
      ),
      locale: const Locale('ar'),
    ));
    await tester.pump();

    // The gate builds under ar/RTL and the keypad renders.
    expect(find.byType(MathGate), findsOneWidget);
    expect(find.byKey(const ValueKey('mathkey_1')), findsOneWidget);

    await tapDigits(tester, '12');
    await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
    await tester.pump();

    expect(unlocked, isTrue,
        reason: 'the parental math gate must work identically under ar/RTL');
  });
}
