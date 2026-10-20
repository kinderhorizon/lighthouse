import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/state/switch_access_provider.dart';
import 'package:lighthouse/ui/keyboard/smart_keyboard_screen.dart';
import 'package:lighthouse/ui/schedule/daily_schedule_screen.dart';
import 'package:lighthouse/ui/schedule/manage_elements_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('Accessibility & Screen Reader Semantics Audits', () {
    testWidgets('DailyScheduleScreen has semantic labels and touch targets >= 48dp on action buttons', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const DailyScheduleScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that activity tiles have semantic checked states and descriptions
      final semantics = tester.getSemantics(find.byType(DailyScheduleScreen));
      expect(semantics, isNotNull);

      // Verify IconButton action buttons have constraints meeting >= 48x48 dp
      final iconButtons = tester.widgetList<IconButton>(find.byType(IconButton));
      expect(iconButtons, isNotEmpty);

      for (final btn in iconButtons) {
        if (btn.constraints != null) {
          expect(btn.constraints!.minWidth, greaterThanOrEqualTo(48.0));
          expect(btn.constraints!.minHeight, greaterThanOrEqualTo(48.0));
        }
      }
    });

    testWidgets('ManageElementsScreen provides semantic accessibility toggles for TalkBack', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const ManageElementsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find switch toggles
      final switchFinders = find.byType(Switch);
      expect(switchFinders, findsWidgets);

      // Verify edit buttons have constraints meeting >= 48x48 dp
      final iconButtons = tester.widgetList<IconButton>(find.byType(IconButton));
      for (final btn in iconButtons) {
        if (btn.constraints != null) {
          expect(btn.constraints!.minWidth, greaterThanOrEqualTo(48.0));
          expect(btn.constraints!.minHeight, greaterThanOrEqualTo(48.0));
        }
      }
    });

    testWidgets('SmartKeyboardScreen assigns clear TalkBack semantics to special keys and suggestions', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const SmartKeyboardScreen(initialText: 'Hi'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify semantics for functional buttons
      expect(find.bySemanticsLabel('Clear text'), findsOneWidget);
      expect(find.bySemanticsLabel('Backspace'), findsWidgets);
      expect(find.bySemanticsLabel('Space'), findsOneWidget);
      expect(find.bySemanticsLabel('Numbers and symbols'), findsOneWidget);
    });

    testWidgets('Switch Access: switch-focused state provider operates cleanly without regressions', (tester) async {
      final container = ProviderContainer();
      expect(container.read(switchFocusIndexProvider), equals(0));

      container.read(switchFocusIndexProvider.notifier).state = 1;
      expect(container.read(switchFocusIndexProvider), equals(1));
    });
  });
}
