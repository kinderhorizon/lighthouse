/// Board editor, ADR 0022 flows, end to end through the real providers and
/// composition (in-memory stores + a fake registry): "+ Add" asks where, adding
/// a coloured button or a category, replacing a word on a full page, editing
/// and deleting the parent's own tiles, the word coming back, "Start this page
/// blank", and the sheet offering the right actions for each kind of tile.
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
import 'package:lighthouse/ui/edit/custom_tile_dialog.dart';
import 'package:lighthouse/ui/widgets/tile_color_picker.dart';
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

AACButton _word(String id, int row, int col, {String category = 'food'}) =>
    AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: category,
      baseWeight: 0.5,
      iconUri: '',
      voiceOut: id,
    );

/// A FULL 2x3 Home: five words and the Food folder.
AACBoard _home() => AACBoard(
      schemaVersion: '1.3',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 2, cols: 3),
      colorKey: const {
        'food': '#FFD9A6',
        'verb': '#C2FFC2',
        'food_nav': '#FFD9A6',
      },
      buttons: [
        _word('want', 0, 0, category: 'verb'),
        _word('eat', 0, 1, category: 'verb'),
        _word('drink', 0, 2, category: 'verb'),
        _word('more', 1, 0),
        _word('stop', 1, 1),
        const AACButton(
          id: 'fld_food',
          label: 'Food',
          labelByLocale: {},
          type: AACButtonType.folder,
          position: (row: 1, col: 2),
          category: 'food_nav',
          baseWeight: 0.5,
          iconUri: '',
          linkId: 'board_food',
        ),
      ],
    );

/// Food: one word, three empty squares.
AACBoard _food() => AACBoard(
      schemaVersion: '1.3',
      boardId: 'board_food',
      boardName: 'Food',
      gridDimensions: (rows: 2, cols: 2),
      colorKey: const {'food': '#FFD9A6'},
      buttons: [_word('apple', 0, 0)],
    );

class _Env {
  _Env({List<CustomButton>? seed, String root = 'core_main'})
      : buttons = FakeCustomButtonStore(seed),
        rootId = root {
    container = ProviderContainer(overrides: [
      boardRegistryProvider.overrideWith((ref) async =>
          _FakeRegistry({'core_main': _home(), 'board_food': _food()})),
      ...fakeStoreOverrides(buttons: buttons, hidden: hidden, voices: voices),
    ]);
  }

  final FakeCustomButtonStore buttons;
  final hidden = FakeHiddenStore();
  final voices = FakeVoiceStore();
  final String rootId;
  late final ProviderContainer container;

  List<CustomButton> get customs =>
      container.read(customButtonsProvider).valueOrNull ?? const [];

  Widget host({Locale locale = const Locale('en')}) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('es'), Locale('ar')],
          locale: locale,
          // Reduced motion: the jiggle never settles otherwise.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: BoardEditScreen(rootBoardId: rootId),
        ),
      );
}

Future<void> _open(WidgetTester tester, _Env env,
    {Locale locale = const Locale('en')}) async {
  addTearDown(env.container.dispose);
  await tester.pumpWidget(env.host(locale: locale));
  await tester.pumpAndSettle();
}

/// Lets a toast time out so no timer is pending at teardown.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Finder _tile(String id) => find.byKey(ValueKey('editor_tile_$id'));

Future<void> _typeAndSave(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('custom_tile_label')), text);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('custom_tile_save')));
  await tester.tap(find.byKey(const ValueKey('custom_tile_save')));
  await tester.pumpAndSettle();
}

CustomButton _seed(String id,
        {String boardId = 'core_main',
        int row = 0,
        int col = 0,
        String? replaces,
        String? link,
        TileColor? color}) =>
    CustomButton(
      id: id,
      boardId: boardId,
      row: row,
      col: col,
      label: id,
      voiceOut: id,
      imagePath: '',
      replacesId: replaces,
      linkId: link,
      tileColor: color,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'tip_seen.editor': true,
      }));

  group('the sheet offers what fits the tile', () {
    testWidgets('a built-in word: record, picture, pin, hide, put your own here',
        (tester) async {
      final env = _Env();
      await _open(tester, env);
      await tester.tap(_tile('eat'));
      await tester.pumpAndSettle();
      expect(find.text('Record voice'), findsOneWidget);
      expect(find.text('Replace picture'), findsOneWidget);
      expect(find.text('Pin to favourites'), findsOneWidget);
      expect(find.text('Hide from the board'), findsOneWidget);
      expect(find.text('Put your own button here'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete button'), findsNothing);
    });

    testWidgets('your own word: edit first, delete last, no replace',
        (tester) async {
      final env = _Env(seed: [_seed('mine', replaces: 'eat', row: 0, col: 1)]);
      await _open(tester, env);
      await tester.tap(_tile('mine'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Word, picture, and colour'), findsOneWidget);
      expect(find.text('Delete button'), findsOneWidget);
      expect(find.text('Replace picture'), findsNothing);
      expect(find.text('Put your own button here'), findsNothing);
    });

    testWidgets('your own category: open, edit, hide, delete category',
        (tester) async {
      final env = _Env(seed: [_seed('School', replaces: 'stop', row: 1, col: 1,
          link: 'cat_0', color: TileColor.yellow)]);
      await _open(tester, env);
      await tester.tap(_tile('School'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Name, picture, and colour'), findsOneWidget);
      expect(find.text('Delete category'), findsOneWidget);
      expect(find.text('Record voice'), findsNothing);
      expect(find.text('Pin to favourites'), findsNothing);
    });

    testWidgets('a built-in folder still just opens (no sheet)', (tester) async {
      final env = _Env();
      await _open(tester, env);
      await tester.tap(find.byKey(const ValueKey('editor_folder_fld_food')));
      await tester.pumpAndSettle();
      expect(find.text('Food'), findsWidgets); // app bar title of Food
      expect(find.byKey(const ValueKey('editor_tile_apple')), findsOneWidget);
    });
  });

  group('+ Add', () {
    testWidgets('on a page with space: tap an empty square, colour starts on '
        'the page colour, save', (tester) async {
      final env = _Env(root: 'board_food');
      await _open(tester, env);
      await tester.tap(find.byKey(const ValueKey('editor_add')));
      await tester.pumpAndSettle();
      expect(find.text('Where should it go?'), findsOneWidget);
      expect(
          find.text('Tap an empty square, or tap a word to put your new button '
              'in its place.'),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('editor_empty_1_1')));
      await tester.pumpAndSettle();
      expect(find.text('Add to this page'), findsOneWidget);
      // Food is orange, so a new Food button starts orange.
      expect(find.text('Orange: things, food, and places'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('tile_color_green')));
      await tester.tap(find.byKey(const ValueKey('tile_color_green')));
      await tester.pump();
      await _typeAndSave(tester, 'Pizza');

      final b = env.customs.single;
      expect(b.label, 'Pizza');
      expect(b.tileColor, TileColor.green);
      expect(b.boardId, 'board_food');
      expect((b.row, b.col), (1, 1));
      expect(b.replacesId, isNull);
      // Back to arranging, and the tile is on the grid.
      expect(find.byKey(const ValueKey('editor_add')), findsOneWidget);
      expect(_tile(b.id), findsOneWidget);
    });

    testWidgets('on a FULL page: it says so, folders are not choosable, a word '
        'is replaced', (tester) async {
      final env = _Env();
      await _open(tester, env);
      await tester.tap(find.byKey(const ValueKey('editor_add')));
      await tester.pumpAndSettle();
      expect(find.textContaining('This page is full.'), findsOneWidget);

      // A built-in folder cannot be chosen.
      await tester.tap(find.byKey(const ValueKey('editor_folder_fld_food')));
      await tester.pumpAndSettle();
      expect(find.text('Where should it go?'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(_tile('eat'));
      await tester.pumpAndSettle();
      expect(find.text('In place of "eat"'), findsOneWidget);
      expect(
          find.text('"eat" is set aside, not deleted. Delete your new button '
              'to bring it back.'),
          findsOneWidget);
      // Home mixes colours, so it starts grey.
      expect(find.text('Grey: no colour group'), findsOneWidget);
      await _typeAndSave(tester, 'Pizza');

      final b = env.customs.single;
      expect(b.replacesId, 'eat');
      expect(_tile('eat'), findsNothing);
      expect(_tile(b.id), findsOneWidget);
      // It sits exactly where "eat" was.
      final board = (await env.container.read(editableBoardsProvider.future))
          .firstWhere((x) => x.boardId == 'core_main');
      expect(board.buttonAt((row: 0, col: 1))?.id, b.id);
    });

    testWidgets('Cancel returns to arranging without adding', (tester) async {
      final env = _Env();
      await _open(tester, env);
      await tester.tap(find.byKey(const ValueKey('editor_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor_place_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor_add')), findsOneWidget);
      expect(env.customs, isEmpty);
    });

    testWidgets('cancelling the dialog also leaves add mode', (tester) async {
      final env = _Env(root: 'board_food');
      await _open(tester, env);
      await tester.tap(find.byKey(const ValueKey('editor_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor_empty_0_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor_add')), findsOneWidget);
      expect(env.customs, isEmpty);
    });
  });

  group('categories', () {
    testWidgets('make one, open it, fill it, come back', (tester) async {
      final env = _Env(root: 'board_food');
      await _open(tester, env);
      await tester.tap(find.byKey(const ValueKey('editor_empty_0_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('custom_tile_kind_category')));
      await tester.pumpAndSettle();
      expect(find.text('Category name'), findsOneWidget);
      expect(find.textContaining('A folder that opens its own page'),
          findsOneWidget);
      // A category never speaks: no voice recorder.
      expect(find.text('Record your own voice (optional)'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('tile_color_yellow')));
      await tester.tap(find.byKey(const ValueKey('tile_color_yellow')));
      await tester.pump();
      await _typeAndSave(tester, 'Snacks');

      final folder = env.customs.single;
      expect(folder.isCategory, isTrue);
      expect(folder.tileColor, TileColor.yellow);

      // Tap it: the sheet opens with Open first.
      await tester.tap(_tile(folder.id));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet_open')));
      await tester.pumpAndSettle();
      expect(find.text('Snacks'), findsWidgets);
      expect(find.byKey(const ValueKey('editor_nav_back')), findsOneWidget);

      // Fill it: words there start in the category's colour.
      await tester.tap(find.byKey(const ValueKey('editor_empty_0_0')));
      await tester.pumpAndSettle();
      expect(find.text('Yellow: people and pronouns'), findsOneWidget);
      await _typeAndSave(tester, 'Crackers');
      final inside = env.customs.firstWhere((c) => c.label == 'Crackers');
      expect(inside.boardId, folder.linkId);
      expect(inside.tileColor, TileColor.yellow);

      await tester.tap(find.byKey(const ValueKey('editor_nav_back')));
      await tester.pumpAndSettle();
      expect(_tile(folder.id), findsOneWidget);
    });

    testWidgets('deleting a category asks first, with how much goes with it',
        (tester) async {
      final env = _Env(root: 'board_food', seed: [
        _seed('Snacks', boardId: 'board_food', row: 0, col: 1, link: 'cat_0'),
        _seed('Crackers', boardId: 'cat_0'),
        _seed('Chips', boardId: 'cat_0', col: 1),
      ]);
      await _open(tester, env);
      await tester.tap(_tile('Snacks'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet_delete')));
      await tester.pumpAndSettle();
      expect(
          find.text('Delete "Snacks"? Its page and the 2 buttons on it will be '
              'deleted too.'),
          findsOneWidget);

      // Cancel keeps everything.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(env.customs, hasLength(3));

      await tester.tap(_tile('Snacks'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('editor_delete_confirm')));
      await tester.pumpAndSettle();
      expect(env.customs, isEmpty);
      expect(_tile('Snacks'), findsNothing);
      await _drain(tester);
    });
  });

  group('your own tiles', () {
    testWidgets('edit: fix the word and change the colour', (tester) async {
      final env = _Env(root: 'board_food',
          seed: [_seed('Piza', boardId: 'board_food', col: 1)]);
      await _open(tester, env);
      await tester.tap(_tile('Piza'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet_edit')));
      await tester.pumpAndSettle();
      expect(find.text('Edit button'), findsOneWidget);
      // Prefilled with the current word; no Button/Category switch when editing.
      expect(find.widgetWithText(TextField, 'Piza'), findsOneWidget);
      expect(find.byKey(const ValueKey('custom_tile_kind')), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('tile_color_blue')));
      await tester.tap(find.byKey(const ValueKey('tile_color_blue')));
      await tester.pump();
      await _typeAndSave(tester, 'Pizza');
      final b = env.customs.single;
      expect(b.id, 'Piza');
      expect(b.label, 'Pizza');
      expect(b.tileColor, TileColor.blue);
      expect(find.text('Saved'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('deleting a replacement brings the word back and says so',
        (tester) async {
      final env = _Env(seed: [_seed('Pizza', replaces: 'eat', row: 0, col: 1)]);
      await _open(tester, env);
      expect(_tile('eat'), findsNothing);
      await tester.tap(_tile('Pizza'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet_delete')));
      await tester.pumpAndSettle();
      expect(find.text('"eat" is back'), findsOneWidget);
      expect(_tile('eat'), findsOneWidget);
      expect(env.customs, isEmpty);
      await _drain(tester);
    });

    testWidgets('a word sheet "Put your own button here" replaces that word',
        (tester) async {
      final env = _Env();
      await _open(tester, env);
      await tester.tap(_tile('drink'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sheet_replace')));
      await tester.pumpAndSettle();
      expect(find.text('In place of "drink"'), findsOneWidget);
      await _typeAndSave(tester, 'Juice');
      expect(env.customs.single.replacesId, 'drink');
      expect(_tile('drink'), findsNothing);
    });

    testWidgets('select mode cannot tick a category', (tester) async {
      final env = _Env(root: 'board_food', seed: [
        _seed('Snacks', boardId: 'board_food', row: 0, col: 1, link: 'cat_0'),
      ]);
      await _open(tester, env);
      await tester.tap(find.byKey(const ValueKey('editor_select')));
      await tester.pumpAndSettle();
      await tester.tap(_tile('Snacks'));
      await tester.pumpAndSettle();
      expect(find.text('Select tiles'), findsOneWidget); // still 0 selected
      await tester.tap(_tile('apple'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsWidgets);
    });
  });

  testWidgets('Start this page blank hides every word, never a folder',
      (tester) async {
    final env = _Env(seed: [_seed('Mine', replaces: 'eat', row: 0, col: 1)]);
    await _open(tester, env);
    await tester.tap(find.byKey(const ValueKey('editor_reset_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start this page blank'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hide every word on this page?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor_reset_confirm')));
    await tester.pumpAndSettle();

    final hidden = env.hidden.h.forBoard('core_main');
    expect(hidden, {'want', 'Mine', 'drink', 'more', 'stop'});
    expect(hidden.contains('fld_food'), isFalse);
    expect(find.text('All words hidden'), findsOneWidget);
    await _drain(tester);
  });

  // Real phone sizes (iPhone SE / 8 = 375x667, iPhone 15 = 390x844) at
  // normal and large text. Spanish is checked on a wider phone: the editor's
  // EXISTING top bar (Share / menu / Seleccionar / Hecho) already overflows
  // at 375-390 in Spanish, independent of this feature.
  const cases = [
    (Locale('en'), Size(375, 667), 1.0),
    (Locale('en'), Size(375, 667), 1.3),
    (Locale('en'), Size(390, 844), 1.5),
    (Locale('ar'), Size(375, 667), 1.0),
    (Locale('ar'), Size(375, 667), 1.3),
    (Locale('ar'), Size(390, 844), 1.5),
    (Locale('es'), Size(820, 1180), 1.0),
    (Locale('es'), Size(820, 1180), 1.5),
  ];
  for (final (locale, size, scale) in cases) {
    testWidgets('${locale.languageCode} ${size.width.toInt()}x'
        '${size.height.toInt()} text x$scale: the add flow fits', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final env = _Env();
      addTearDown(env.container.dispose);
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: env.host(locale: locale),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('editor_add')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(_tile('eat'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('custom_tile_kind_category')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TileColorPicker), findsOneWidget);
      // Save is reachable.
      await tester.ensureVisible(find.byKey(const ValueKey('custom_tile_save')));
      expect(tester.takeException(), isNull);
    });
  }

  // The smallest Android phones (320x533) with the keyboard up leave ~270pt:
  // Save must still be fully above the keyboard in every mode and language.
  for (final locale in const [Locale('en'), Locale('ar'), Locale('es')]) {
    testWidgets('${locale.languageCode}: every dialog mode keeps Save above '
        'the keyboard on a 320x533 phone', (tester) async {
      const size = Size(320, 533);
      const keyboard = 260.0;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final env = _Env();
      addTearDown(env.container.dispose);
      for (final dialog in <Widget>[
        const CustomTileDialog.add(boardId: 'board_food', slot: (row: 0, col: 1)),
        CustomTileDialog.add(
            boardId: 'core_main', slot: (row: 0, col: 1),
            replacing: _word('eat', 0, 1)),
        CustomTileDialog.edit(existing: _seed('Snacks', link: 'cat_0')),
      ]) {
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(
              size: size, viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: UncontrolledProviderScope(
            container: env.container,
            child: MaterialApp(
              key: UniqueKey(), // a fresh navigator: no dialog left open
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'), Locale('es'), Locale('ar'),
              ],
              locale: locale,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        showDialog<void>(context: context, builder: (_) => dialog),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final save = tester.getRect(find.byKey(const ValueKey('custom_tile_save')));
        expect(save.bottom, lessThanOrEqualTo(size.height - keyboard),
            reason: 'Save must be fully above the keyboard');
      }
    });
  }

  // The dialog itself on the smallest phone with the largest text, in every
  // mode and language.
  for (final locale in const [Locale('en'), Locale('ar'), Locale('es')]) {
    testWidgets('${locale.languageCode}: every dialog mode fits 320x568 at '
        'text x1.5', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final env = _Env();
      addTearDown(env.container.dispose);
      Future<void> show(Widget dialog) async {
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 568), textScaler: TextScaler.linear(1.5)),
          child: UncontrolledProviderScope(
            container: env.container,
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'), Locale('es'), Locale('ar'),
              ],
              locale: locale,
              home: Scaffold(body: Center(child: dialog)),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(const CustomTileDialog.add(
          boardId: 'board_food', slot: (row: 0, col: 1),
          initialColor: TileColor.orange));
      await tester.tap(find.byKey(const ValueKey('custom_tile_kind_category')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await show(CustomTileDialog.add(
          boardId: 'core_main', slot: (row: 0, col: 1),
          replacing: _word('eat', 0, 1)));
      await show(CustomTileDialog.edit(
          existing: _seed('Snacks', link: 'cat_0', color: TileColor.pink)));
      await show(CustomTileDialog.edit(existing: _seed('Pizza')));
    });
  }
}
