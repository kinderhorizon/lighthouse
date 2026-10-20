import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/schedule/daily_schedule_store.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/schedule/activity_expression_sheet.dart';
import 'package:lighthouse/ui/schedule/daily_schedule_screen.dart';
import 'package:lighthouse/ui/schedule/first_then_view.dart';
import 'package:lighthouse/ui/schedule/visual_timer_view.dart';

class _FakeProfileStore extends ProfileStore {
  @override
  Future<UserProfile> getActiveProfile() async => UserProfile(
        id: 'test_user',
        name: 'Tester',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}

class _FakeDailyScheduleStore extends DailyScheduleStore {
  DailySchedule? _schedule;

  @override
  Future<DailySchedule> loadSchedule(String profileId, [String? dateString]) async {
    return _schedule ?? defaultStarterSchedule(profileId, dateString);
  }

  @override
  Future<void> saveSchedule(String profileId, DailySchedule schedule) async {
    _schedule = schedule;
  }
}

class _MockTTS implements TTSEngine {
  @override
  Future<void> speak(String text, {required Locale locale}) async {}
  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {}
  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async => true;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> setPitch(double pitch) async {}
}

void main() {
  testWidgets('DailyScheduleScreen renders tabs, displays activities and transitions', (tester) async {
    final mockStore = _FakeDailyScheduleStore();

    // Save a known schedule
    await mockStore.saveSchedule(
      'test_user',
      const DailySchedule(
        id: 'test_sched',
        profileId: 'test_user',
        date: '2026-10-19',
        firstActivityId: 'act_1',
        thenActivityId: 'act_2',
        activities: [
          ScheduleActivity(
            id: 'act_1',
            title: 'Eat Breakfast',
            time: '08:00',
            imageUri: '',
            durationMinutes: 20,
            category: ScheduleActivityCategory.meal,
            labelsByLocale: {'en': 'Eat Breakfast', 'de': 'Frühstücken', 'ar': 'تناول الفطور', 'ar_dz': 'الفطور'},
          ),
          ScheduleActivity(
            id: 'act_2',
            title: 'Brush Teeth',
            time: '08:25',
            imageUri: '',
            durationMinutes: 10,
            category: ScheduleActivityCategory.hygiene,
            labelsByLocale: {'en': 'Brush Teeth', 'de': 'Zähne putzen', 'ar': 'تنظيف الأسنان', 'ar_dz': 'غسل السنان'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyScheduleStoreProvider.overrideWithValue(mockStore),
          profileStoreProvider.overrideWithValue(_FakeProfileStore()),
          ttsEngineProvider.overrideWithValue(_MockTTS()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DailyScheduleScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Verify Schedule Tab elements
    expect(find.text('Routines & Time'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('First / Then'), findsOneWidget);
    expect(find.text('Timer'), findsOneWidget);
    expect(find.text('Eat Breakfast'), findsOneWidget);
    expect(find.text('Brush Teeth'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);

    // Tap on First activity -> opens ActivityExpressionSheet
    await tester.tap(find.text('Eat Breakfast'));
    await tester.pumpAndSettle();

    // Verify expression sheet items
    expect(find.byType(ActivityExpressionSheet), findsOneWidget);
    expect(find.text('I want Eat Breakfast'), findsOneWidget);
    expect(find.text('When is Eat Breakfast?'), findsOneWidget);

    // Close bottom sheet (tap drag handle or barrier)
    Navigator.of(tester.element(find.byType(ActivityExpressionSheet))).pop();
    await tester.pumpAndSettle();

    // Switch to First / Then Tab
    await tester.tap(find.text('First / Then'));
    await tester.pumpAndSettle();

    expect(find.byType(FirstThenView), findsOneWidget);
    expect(find.text('1. FIRST'), findsOneWidget);
    expect(find.text('2. THEN'), findsOneWidget);

    // Switch to Timer Tab
    await tester.tap(find.text('Timer'));
    await tester.pumpAndSettle();

    expect(find.byType(VisualTimerView), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
