/// Custom-button editor screen (ADR 0012).
///
/// Uses an in-memory fake store so the widget tests never touch real file IO
/// (real readAsString does not complete under pumpAndSettle's fake-async, which
/// would hang the loading spinner). The store's real IO is covered separately
/// in custom_button_store_test.dart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';

import '../../support/fake_stores.dart';

AACBoard _fakeBoard() => AACBoard.fromJson({
      'schema_version': '1.0',
      'board_id': 'board_food',
      'board_name': 'Food',
      'grid_dimensions': [2, 2],
      'color_key': {},
      'buttons': [
        {
          'id': 'btn_food_apple',
          'label': 'Apple',
          'type': 'word',
          'voice_out': 'apple',
          'position': {'row': 0, 'col': 0},
          'category': 'food',
        },
      ],
    });

Widget _host(FakeCustomButtonStore store) {
  return ProviderScope(
    overrides: [
      ...fakeStoreOverrides(buttons: store),
      editableBoardsProvider.overrideWith((ref) async => [_fakeBoard()]),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [Locale('en')],
      home: CustomButtonsScreen(),
    ),
  );
}

const _seedCup = CustomButton(
  id: 'custom_board_food_seed',
  boardId: 'board_food',
  row: 0,
  col: 1,
  label: 'Cup',
  voiceOut: 'cup',
  imagePath: '',
);

void main() {
  testWidgets('empty state when there are no custom buttons', (tester) async {
    await tester.pumpWidget(_host(FakeCustomButtonStore()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Make a button for your child'), findsOneWidget);
  });

  testWidgets('lists a persisted custom button and deletes it', (tester) async {
    await tester.pumpWidget(_host(FakeCustomButtonStore([_seedCup])));
    await tester.pumpAndSettle();

    expect(find.text('Cup'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget); // localized board name

    await tester.tap(find.byTooltip('Delete button'));
    await tester.pumpAndSettle();
    expect(find.text('Cup'), findsNothing);
    expect(find.textContaining('Make a button for your child'), findsOneWidget);
  });

  testWidgets('add flow: pick board, type a word, save (text-only)',
      (tester) async {
    await tester.pumpWidget(_host(FakeCustomButtonStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add your first button'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food (3)').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sippy cup');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Dialog closed and the new button is listed.
    expect(find.text('Sippy cup'), findsOneWidget);
  });
}
