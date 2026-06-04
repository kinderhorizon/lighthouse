/// PROOF (local dev tool, not CI): boots the full app on a simulator, opens the
/// board editor through the math gate, and screenshots the first-use tip so we
/// can SEE that it renders. Run with:
///   flutter drive --driver=test_driver/screenshot_driver.dart \
///     --target=integration_test/editor_tip_proof_test.dart -d <sim-id>
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lighthouse/main.dart';
import 'package:lighthouse/persistence/persistence.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editor first-use tip is visible', (tester) async {
    // Fresh state: onboarding already done (boot straight to the board), and
    // no tip flags set (every tip is unseen).
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding.completed': true,
    });
    final tmp = await Directory.systemTemp.createTemp('lh_tipproof_');
    final isar = await IsarSetup.openAt(tmp, name: 'tipproof');
    final crashStore = CrashLogStore();
    final crashCapture = CrashCapture(
      store: crashStore,
      deviceInfoSource: DeviceInfoSource(),
    );

    Future<void> settle([int ms = 700]) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: ms));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          crashLogStoreProvider.overrideWithValue(crashStore),
          crashCaptureProvider.overrideWithValue(crashCapture),
          isarProvider.overrideWithValue(isar),
        ],
        child: const LighthouseApp(),
      ),
    );
    await settle(1800);
    await binding.takeScreenshot('01_home');

    // Open the board editor (gear+ icon in the home app bar).
    await tester.tap(find.byIcon(Icons.dashboard_customize_outlined));
    await settle(900);
    // The math-gate first-use tip shows here on first run: capture it, then
    // dismiss it so it does not cover the keypad.
    await binding.takeScreenshot('02_math_gate_with_tip');
    final gotIt = find.byKey(const ValueKey('tip_gotit'));
    if (gotIt.evaluate().isNotEmpty) {
      await tester.tap(gotIt.first);
      await settle(400);
    }

    // Solve the random sum read off the equation.
    final re = RegExp(r'(\d+)\s*\+\s*(\d+)');
    int? a, b;
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      final d = w.data;
      if (d == null) continue;
      final m = re.firstMatch(d);
      if (m != null) {
        a = int.parse(m.group(1)!);
        b = int.parse(m.group(2)!);
        break;
      }
    }
    for (final ch in (a! + b!).toString().split('')) {
      await tester.tap(find.byKey(ValueKey('mathkey_$ch')));
      await settle(150);
    }
    await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
    await settle(1500);

    // Editor is now open. Poll a few frames for the tip to lay out (the board
    // loads asynchronously), then screenshot + assert.
    for (var i = 0;
        i < 40 && find.text('Editing your board').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await binding.takeScreenshot('03_editor_with_tip');
    expect(find.text('Editing your board'), findsOneWidget);
    expect(find.byKey(const ValueKey('tip_gotit')), findsOneWidget);
  });
}
