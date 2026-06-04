import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/persistence/persistence.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/settings/settings_advanced_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localized.dart';

class _FakeRepo implements BanditRepository {
  int clearCount = 0;

  @override
  Future<void> clearAll() async {
    clearCount++;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  Future<_FakeRepo> pumpScreen(WidgetTester tester) async {
    final repo = _FakeRepo();
    final ctx = ContextManager();
    // Seed some in-memory context so reset has something to clear.
    ctx.recordTap(AACButtonStub.help);

    // Tall viewport so every advanced tile is laid out (the ListView only
    // builds visible rows; the Reset tile sits at the bottom).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          banditRepositoryProvider.overrideWith((ref) => repo),
          contextManagerProvider.overrideWith((ref) => ctx),
        ],
        child: localizedApp(const SettingsAdvancedScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('Reset tile shows a confirmation dialog before erasing',
      (tester) async {
    final repo = await pumpScreen(tester);

    await tester.tap(find.text('Reset what Lighthouse has learned'));
    await tester.pumpAndSettle();

    // Dialog is up; nothing cleared yet.
    expect(find.text('Reset learned state?'), findsOneWidget);
    expect(repo.clearCount, 0);
  });

  testWidgets('Cancel leaves learned state intact', (tester) async {
    final repo = await pumpScreen(tester);

    await tester.tap(find.text('Reset what Lighthouse has learned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.clearCount, 0);
    expect(find.text('Reset learned state?'), findsNothing);
  });

  testWidgets('Erase calls clearAll and confirms via snackbar',
      (tester) async {
    final repo = await pumpScreen(tester);

    await tester.tap(find.text('Reset what Lighthouse has learned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();

    expect(repo.clearCount, 1);
    expect(find.text('Learned state cleared.'), findsOneWidget);
  });
}

/// Minimal AACButton fixtures for seeding the context manager.
class AACButtonStub {
  static final help = AACButton(
    id: 'btn_help',
    label: 'Help',
    labelByLocale: const {},
    type: AACButtonType.word,
    position: (row: 0, col: 0),
    category: 'needs',
    baseWeight: 0.9,
    iconUri: '',
    voiceOut: 'help',
  );
}
