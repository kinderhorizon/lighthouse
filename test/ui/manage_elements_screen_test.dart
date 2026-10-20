import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/schedule/daily_schedule_store.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/schedule/manage_elements_screen.dart';

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

void main() {
  testWidgets('ManageElementsScreen renders 3 tabs, searches elements and filters categories', (tester) async {
    final mockStore = _FakeDailyScheduleStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyScheduleStoreProvider.overrideWithValue(mockStore),
          profileStoreProvider.overrideWithValue(_FakeProfileStore()),
        ],
        child: const MaterialApp(
          locale: Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ManageElementsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Elemente verwalten'), findsOneWidget);
    expect(find.text('Verfügbare Aktivitäten und Routinenschritte anpassen.'), findsOneWidget);

    // Verify Segmented Tabs
    expect(find.text('Routinen'), findsOneWidget);
    expect(find.text('Kategorien'), findsOneWidget);
    expect(find.text('Uploads'), findsOneWidget);

    // Verify search and category filter bar
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Alle (24)'), findsOneWidget);
    expect(find.text('Aufstehen'), findsOneWidget);

    // Search for "Zähne"
    await tester.enterText(find.byType(TextField), 'Zähne');
    await tester.pumpAndSettle();

    expect(find.text('Zähne putzen'), findsOneWidget);
    expect(find.text('Aufstehen'), findsNothing);

    // Clear search
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.text('Aufstehen'), findsOneWidget);

    // Switch to Kategorien Tab
    await tester.tap(find.text('Kategorien'));
    await tester.pumpAndSettle();

    expect(find.text('Morgen & Routine'), findsOneWidget);
    expect(find.text('Freizeit & Draußen'), findsOneWidget);

    // Switch to Uploads Tab
    await tester.tap(find.text('Uploads'));
    await tester.pumpAndSettle();

    expect(find.text('Eigene Bilder & Symbole'), findsOneWidget);
    expect(find.text('Foto auswählen'), findsOneWidget);
  });
}
