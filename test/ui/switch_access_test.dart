import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/settings/settings_repository.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/aac_button_tile.dart';
import 'package:lighthouse/ui/a11y/switch_scanner.dart';
import 'package:lighthouse/ui/theme/lighthouse_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AACButton makeBtn(String id, String label) {
    return AACButton(
      id: id,
      label: label,
      labelByLocale: {'en': label},
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: 'needs',
      baseWeight: 1.0,
      voiceOut: label,
      voiceOutByLocale: {'en': label},
      iconUri: 'test.svg',
    );
  }

  testWidgets('AACButtonTile renders 3.5px amber border when switch-focused', (tester) async {
    final btn = makeBtn('btn_water', 'Water');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: AACButtonTile(
                button: btn,
                colorKey: const {'needs': '#FFE0B2'},
                isSwitchFocused: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify DecoratedBox contains the 3.5px amber border
    final decoratedBoxes = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    final hasAmberFocusBorder = decoratedBoxes.any((box) {
      final decor = box.decoration;
      if (decor is BoxDecoration && decor.border is Border) {
        final border = decor.border as Border;
        return border.top.color == LhColors.amber && border.top.width == 3.5;
      }
      return false;
    });

    expect(hasAmberFocusBorder, isTrue);
  });

  testWidgets('Dual-switch mode: Step moves focus, Select invokes callback', (tester) async {
    final btn1 = makeBtn('btn_1', 'One');
    final btn2 = makeBtn('btn_2', 'Two');
    final btn3 = makeBtn('btn_3', 'Three');

    final testBoard = AACBoard(
      schemaVersion: '1.0',
      boardId: 'test_board',
      boardName: 'Test',
      gridDimensions: (rows: 1, cols: 3),
      colorKey: {},
      buttons: [btn1, btn2, btn3],
    );

    AACButton? selectedButton;

    final container = ProviderContainer(
      overrides: [
        settingsNotifierProvider.overrideWith(() => _MockDualSwitchNotifier()),
      ],
    );


    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SwitchScanner(
              board: testBoard,
              onSelect: (btn) => selectedButton = btn,
              child: const SizedBox(height: 200),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dual switch on-screen controls are visible
    expect(find.text('STEP (Space)'), findsOneWidget);
    expect(find.text('SELECT (Enter)'), findsOneWidget);

    // Initial focus index is 0 (btn1)
    expect(container.read(switchFocusIndexProvider), 0);

    // Tap STEP button
    await tester.tap(find.text('STEP (Space)'));
    await tester.pumpAndSettle();
    expect(container.read(switchFocusIndexProvider), 1); // Now btn2

    // Tap STEP button again
    await tester.tap(find.text('STEP (Space)'));
    await tester.pumpAndSettle();
    expect(container.read(switchFocusIndexProvider), 2); // Now btn3

    // Tap SELECT button
    await tester.tap(find.text('SELECT (Enter)'));
    await tester.pumpAndSettle();

    // Verify selected button was btn3
    expect(selectedButton, equals(btn3));
  });

  testWidgets('Single-switch mode: Dwell timer automatically advances focus', (tester) async {
    final btn1 = makeBtn('btn_1', 'One');
    final btn2 = makeBtn('btn_2', 'Two');

    final testBoard = AACBoard(
      schemaVersion: '1.0',
      boardId: 'test_board',
      boardName: 'Test',
      gridDimensions: (rows: 1, cols: 2),
      colorKey: {},
      buttons: [btn1, btn2],
    );

    final container = ProviderContainer(
      overrides: [
        settingsNotifierProvider.overrideWith(() => _MockSingleSwitchNotifier()),
      ],
    );


    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SwitchScanner(
              board: testBoard,
              onSelect: (_) {},
              child: const SizedBox(height: 200),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(container.read(switchFocusIndexProvider), 0);

    // Advance dwell timer by 500ms
    await tester.pump(const Duration(milliseconds: 550));
    expect(container.read(switchFocusIndexProvider), 1);

    // Advance dwell timer again
    await tester.pump(const Duration(milliseconds: 550));
    expect(container.read(switchFocusIndexProvider), 0); // Wraps around
  });
}

class _MockDualSwitchNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async {
    return SettingsState.defaults.copyWith(
      accessMethod: AccessMethod.switchDual,
    );
  }
}

class _MockSingleSwitchNotifier extends SettingsNotifier {
  @override
  Future<SettingsState> build() async {
    return SettingsState.defaults.copyWith(
      accessMethod: AccessMethod.switchSingle,
      switchDwellMs: 500,
    );
  }
}
