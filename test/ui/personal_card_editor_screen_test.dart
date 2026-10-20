import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/cards/personal_card_store.dart';
import 'package:lighthouse/services/profile/profile_store.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/cards/personal_card_editor_screen.dart';

class _FakeProfileStore extends ProfileStore {
  @override
  Future<UserProfile> getActiveProfile() async => UserProfile(
        id: 'test_user',
        name: 'Tester',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}

void main() {
  testWidgets('PersonalCardEditorScreen renders preview and saves card', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('card_test_');
    final mockStore = PersonalCardStore(baseDirOverride: tempDir);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalCardStoreProvider.overrideWithValue(mockStore),
          profileStoreProvider.overrideWithValue(_FakeProfileStore()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => const PersonalCardEditorScreen(
                      initialLabel: 'Grandma',
                      initialBoardId: PersonalBoardId.myFamily,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify Title and Label
    expect(find.text('New Personal Card'), findsOneWidget);
    expect(find.text('GRANDMA'), findsOneWidget); // In WYSIWYG preview

    // Verify Save Button is present
    final saveBtn = find.text('Save Card');
    expect(saveBtn, findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(saveBtn);
      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pump();

    // After save, screen pops back to initial screen
    expect(find.text('Open'), findsOneWidget);
  });
}
