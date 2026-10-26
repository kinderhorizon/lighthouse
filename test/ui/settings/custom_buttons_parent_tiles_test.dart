/// "Your own buttons" (Settings) with ADR 0022: the add dialog's colour starts
/// on the chosen board's colour (and stays the parent's choice once they pick
/// one), the list shows each tile's colour and what kind of tile it is, and
/// deleting a category asks first.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_stores.dart';

class _FakeRegistry extends BoardRegistry {
  _FakeRegistry(this.boards);
  final Map<String, AACBoard> boards;
  @override
  Future<AACBoard?> tryLoad(String boardId) async => boards[boardId];
  @override
  List<String> knownBoardIds() => boards.keys.toList();
  @override
  bool knows(String boardId) => boards.containsKey(boardId);
}

AACButton _word(String id, int row, int col) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: 'food',
      baseWeight: 0.5,
      iconUri: '',
      voiceOut: id,
    );

final _boards = {
  'core_main': AACBoard(
    schemaVersion: '1.3',
    boardId: 'core_main',
    boardName: 'Home',
    gridDimensions: (rows: 1, cols: 3),
    colorKey: const {'food': '#FFD9A6', 'verb': '#C2FFC2'},
    buttons: [_word('want', 0, 0), _word('eat', 0, 1)],
  ),
  'board_people': AACBoard(
    schemaVersion: '1.3',
    boardId: 'board_people',
    boardName: 'People',
    gridDimensions: (rows: 1, cols: 3),
    colorKey: const {'people': '#FFFFA6'},
    buttons: [_word('mom', 0, 0)],
  ),
};

CustomButton _seed(String id,
        {String boardId = 'core_main',
        int col = 2,
        String? replaces,
        String? link,
        TileColor? color}) =>
    CustomButton(
      id: id,
      boardId: boardId,
      row: 0,
      col: col,
      label: id,
      voiceOut: id,
      imagePath: '',
      replacesId: replaces,
      linkId: link,
      tileColor: color,
    );

Widget _host(FakeCustomButtonStore store) => ProviderScope(
      overrides: [
        boardRegistryProvider
            .overrideWith((ref) async => _FakeRegistry(_boards)),
        ...fakeStoreOverrides(buttons: store),
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'tip_seen.buttons': true,
      }));

  testWidgets('the colour follows the chosen board until the parent picks one',
      (tester) async {
    final store = FakeCustomButtonStore();
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your first button'));
    await tester.pumpAndSettle();
    expect(find.text('Grey: no colour group'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('People (2)').last);
    await tester.pumpAndSettle();
    expect(find.text('Yellow: people and pronouns'), findsOneWidget);

    // The parent's own choice sticks even if they change the board.
    await tester.ensureVisible(find.byKey(const ValueKey('tile_color_pink')));
    await tester.tap(find.byKey(const ValueKey('tile_color_pink')));
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home (1)').last);
    await tester.pumpAndSettle();
    expect(find.text('Pink: social words and urgent needs'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Grandma');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final b = store.items.single;
    expect(b.label, 'Grandma');
    expect(b.boardId, 'core_main');
    expect(b.tileColor, TileColor.pink);
  });

  testWidgets('the list shows the kind of tile and its colour', (tester) async {
    await tester.pumpWidget(_host(FakeCustomButtonStore([
      _seed('Pizza', replaces: 'eat', col: 1, color: TileColor.orange),
      _seed('School', link: 'cat_0', color: TileColor.yellow),
      _seed('Pencil', boardId: 'cat_0', col: 0),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('Home, in place of "eat"'), findsOneWidget);
    expect(find.text('Category on Home'), findsOneWidget);
    // A word on a parent-made page names that page.
    expect(find.text('School'), findsNWidgets(2)); // the row title + subtitle
    final swatch = tester.widget<Container>(find
        .ancestor(of: find.byIcon(Icons.folder_outlined), matching: find.byType(Container))
        .first);
    expect((swatch.decoration! as BoxDecoration).color,
        const Color(0xFFFFFFA6));
  });

  testWidgets('deleting a category asks first; deleting a word does not',
      (tester) async {
    final store = FakeCustomButtonStore([
      _seed('School', link: 'cat_0'),
      _seed('Pencil', boardId: 'cat_0', col: 0),
      _seed('Cup', boardId: 'board_people', col: 1),
    ]);
    await tester.pumpWidget(_host(store));
    await tester.pumpAndSettle();

    // The word goes straight away.
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'Cup'),
        matching: find.byTooltip('Delete button')));
    await tester.pumpAndSettle();
    expect(store.items.map((b) => b.id), ['School', 'Pencil']);

    // The category asks, with the count.
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'Category on Home'),
        matching: find.byTooltip('Delete button')));
    await tester.pumpAndSettle();
    expect(
        find.text('Delete "School"? Its page and the 1 button on it will be '
            'deleted too.'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('custom_delete_confirm')));
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
  });
}
