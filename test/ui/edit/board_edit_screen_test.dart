/// Board editor (redesigned, ADR 0019): arrange / quick-action sheet / select
/// batch / hide-show / folder lock / share / reset.
///
/// In-memory fake stores so the widget tests never touch real file IO (real
/// readAsString does not complete under pumpAndSettle's fake-async). The
/// reorder math is unit-tested in board_editor_reorder_test.dart; the stores'
/// real IO is covered in their own tests.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';

import '../../support/fake_stores.dart';

class _FakeLayoutStore implements BoardLayoutStore {
  _FakeLayoutStore([BoardLayout? seed]) : _l = seed ?? const BoardLayout.empty();
  BoardLayout _l;
  @override
  Future<BoardLayout> load() async => _l;
  @override
  Future<void> save(BoardLayout layout) async => _l = layout;
}

class _FakeFavStore implements FavouritesStore {
  _FakeFavStore([List<ButtonRef>? seed]) : _pins = [...?seed];
  final List<ButtonRef> _pins;
  @override
  Future<List<ButtonRef>> pins() async => List.unmodifiable(_pins);

  @override
  Future<List<ButtonRef>> replaceAll(List<ButtonRef> refs) async {
    _pins
      ..clear()
      ..addAll(refs);
    return List.unmodifiable(_pins);
  }
  @override
  Future<List<ButtonRef>> pin(ButtonRef ref) async {
    if (!_pins.contains(ref)) _pins.add(ref);
    return List.unmodifiable(_pins);
  }

  @override
  Future<List<ButtonRef>> unpin(ButtonRef ref) async {
    _pins.removeWhere((r) => r == ref);
    return List.unmodifiable(_pins);
  }
}

class _FakeHiddenStore implements HiddenTilesStore {
  _FakeHiddenStore([HiddenTiles? seed]) : _h = seed ?? const HiddenTiles.empty();
  HiddenTiles _h;
  @override
  Future<HiddenTiles> load() async => _h;
  @override
  Future<void> save(HiddenTiles hidden) async => _h = hidden;
}

class _FakeVoiceStore implements CustomVoiceStore {
  final Map<String, String> _m = {};
  @override
  Future<Map<String, String>> load() async => Map.of(_m);
  @override
  Future<Map<String, String>> importClip(File source,
      {required String buttonId}) async {
    _m[buttonId] = '$buttonId.m4a';
    return Map.of(_m);
  }

  @override
  Future<Map<String, String>> remove(String buttonId) async {
    _m.remove(buttonId);
    return Map.of(_m);
  }

  @override
  Future<Map<String, String>> removeMany(Iterable<String> buttonIds) async {
    final s = buttonIds.toSet();
    _m.removeWhere((k, _) => s.contains(k));
    return Map.of(_m);
  }

  @override
  Future<Map<String, String>> clearAll() async {
    _m.clear();
    return Map.of(_m);
  }
}

class _FakeIconStore implements IconOverrideStore {
  final Map<String, String> _m = {};
  @override
  Future<Map<String, String>> load() async => Map.of(_m);
  @override
  Future<Map<String, String>> setImage(File source,
      {required String boardId, required String buttonId}) async {
    _m['$boardId/$buttonId'] = 'x';
    return Map.of(_m);
  }

  @override
  Future<Map<String, String>> clear(String boardId, String buttonId) async {
    _m.remove('$boardId/$buttonId');
    return Map.of(_m);
  }

  @override
  Future<Map<String, String>> resetBoard(String boardId) async {
    _m.removeWhere((k, _) => k.startsWith('$boardId/'));
    return Map.of(_m);
  }

  @override
  Future<Map<String, String>> resetAll() async {
    _m.clear();
    return Map.of(_m);
  }
}

AACButton _btn(String id, int row, int col, {String category = 'food'}) =>
    AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: category,
      baseWeight: 0.5,
      iconUri: '',
    );

AACBoard _board() => AACBoard(
      schemaVersion: '1.0',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 2, cols: 2),
      colorKey: const {'food': '#FFD9A6'},
      buttons: [_btn('btn_a', 0, 0), _btn('btn_b', 0, 1)],
    );

AACBoard _foodBoard() => AACBoard(
      schemaVersion: '1.0',
      boardId: 'board_food',
      boardName: 'Food',
      gridDimensions: (rows: 1, cols: 2),
      colorKey: const {'food': '#FFD9A6'},
      buttons: [_btn('btn_apple', 0, 0), _btn('btn_banana', 0, 1)],
    );

AACBoard _homeWithFolder() => AACBoard(
      schemaVersion: '1.0',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 1, cols: 2),
      colorKey: const {'food': '#FFD9A6', 'food_nav': '#FFD9A6'},
      buttons: [
        _btn('btn_a', 0, 0),
        AACButton(
          id: 'fld_food',
          label: 'Food',
          labelByLocale: const {},
          type: AACButtonType.folder,
          position: (row: 0, col: 1),
          category: 'food_nav',
          baseWeight: 0.5,
          iconUri: '',
          linkId: 'board_food',
        ),
      ],
    );

ProviderContainer _container({
  List<AACBoard>? boards,
  BoardLayout? seedLayout,
  List<ButtonRef>? seedPins,
  HiddenTiles? seedHidden,
}) {
  final bs = boards ?? [_board()];
  return ProviderContainer(
    overrides: [
      editableBoardsProvider.overrideWith((ref) async => bs),
      defaultBoardProvider.overrideWith((ref) async => bs.first),
      boardLayoutStoreProvider.overrideWithValue(_FakeLayoutStore(seedLayout)),
      favouritesStoreProvider.overrideWithValue(_FakeFavStore(seedPins)),
      hiddenTilesStoreProvider.overrideWithValue(_FakeHiddenStore(seedHidden)),
      customVoiceStoreProvider.overrideWithValue(_FakeVoiceStore()),
      customButtonStoreProvider.overrideWithValue(FakeCustomButtonStore()),
      iconOverrideStoreProvider.overrideWithValue(_FakeIconStore()),
    ],
  );
}

Widget _host(ProviderContainer container, {Locale locale = const Locale('en')}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        locale: locale,
        // Disable animations: the editor's continuous jiggle / waveform never
        // settle otherwise, hanging pumpAndSettle. This is the reduced-motion
        // path the editor already honours.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const BoardEditScreen(rootBoardId: 'core_main'),
      ),
    );

/// Advances past the toast (SnackBar) auto-dismiss so its Timer does not remain
/// pending at test teardown (which the test binding flags as an error).
Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a word opens the quick-action sheet', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor_tile_btn_a')));
    await tester.pumpAndSettle();

    expect(find.text('Record voice'), findsOneWidget);
    expect(find.text('Replace picture'), findsOneWidget);
    expect(find.text('Pin to favourites'), findsOneWidget);
    expect(find.text('Hide from the board'), findsOneWidget);
  });

  testWidgets('pin from the sheet pins the tile to favourites', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor_tile_btn_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to favourites'));
    await tester.pumpAndSettle();

    final pins = container.read(favouritesProvider).valueOrNull ?? const [];
    expect(pins.any((r) => r.boardId == 'core_main' && r.buttonId == 'btn_a'),
        isTrue);
    await _drainToast(tester);
  });

  testWidgets('hide from the sheet hides the tile (child) and shows an eye-off '
      'badge in the editor', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor_tile_btn_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide from the board'));
    await tester.pumpAndSettle();

    final hidden = container.read(hiddenTilesProvider).valueOrNull;
    expect(hidden?.isHidden('core_main', 'btn_a'), isTrue);
    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
    await _drainToast(tester);
  });

  testWidgets('select mode: count is live, All selects every word, batch hide '
      'applies to all', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor_select')));
    await tester.pumpAndSettle();
    expect(find.text('Select tiles'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor_tile_btn_a')));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('editor_selall')));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('editor_bulk_hide')));
    await tester.pumpAndSettle();

    final hidden = container.read(hiddenTilesProvider).valueOrNull;
    expect(hidden?.isHidden('core_main', 'btn_a'), isTrue);
    expect(hidden?.isHidden('core_main', 'btn_b'), isTrue);
    // Returned to arrange mode (Select toggle is back).
    expect(find.byKey(const ValueKey('editor_select')), findsOneWidget);
    await _drainToast(tester);
  });

  testWidgets('select mode: batch pin pins every selected tile', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor_select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor_selall')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor_bulk_pin')));
    await tester.pumpAndSettle();

    final pins = container.read(favouritesProvider).valueOrNull ?? const [];
    expect(pins.length, 2);
    await _drainToast(tester);
  });

  testWidgets('folder is locked and is a doorway into its sub-board',
      (tester) async {
    final container = _container(boards: [_homeWithFolder(), _foodBoard()]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor_folder_fld_food')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_tile_fld_food')), findsNothing);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_nav_back')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor_folder_fld_food')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor_tile_btn_apple')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_nav_back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor_nav_back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor_tile_btn_a')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_tile_btn_apple')), findsNothing);
  });

  testWidgets('empty slots show an add affordance', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor_empty_1_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_empty_1_1')), findsOneWidget);
  });

  testWidgets('reset this board clears its overrides AND un-hides tiles',
      (tester) async {
    final seeded = const BoardLayout.empty()
        .withPosition('core_main', 'btn_a', (row: 1, col: 1));
    // clinical review regression: a hidden tile must be un-hidden by the reset (it
    // previously was not, because the reset only touched the layout).
    final container = _container(
      seedLayout: seeded,
      seedHidden: const HiddenTiles({
        'core_main': {'btn_a'},
      }),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();
    await container.read(boardLayoutProvider.future);
    await container.read(hiddenTilesProvider.future);
    expect(
      container.read(hiddenTilesProvider).valueOrNull?.isHidden(
            'core_main',
            'btn_a',
          ),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('editor_reset_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset this board'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor_reset_confirm')));
    await tester.pumpAndSettle();

    expect(
      container.read(boardLayoutProvider).valueOrNull?.positionOf(
            'core_main',
            'btn_a',
          ),
      isNull,
    );
    expect(
      container.read(hiddenTilesProvider).valueOrNull?.isHidden(
            'core_main',
            'btn_a',
          ),
      isFalse,
    );
  });

  testWidgets('Share opens a confirm dialog and Cancel dismisses', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor_share')));
    await tester.pumpAndSettle();
    expect(find.text('Share this vocabulary?'), findsOneWidget);
    // Tells the sender how the other person opens the file (no sign-in).
    expect(
      find.text('On the other device, open the file and choose Lighthouse '
          'AAC. On an iPhone or iPad, tap Share first. No account or sign-in '
          'is needed.'),
      findsOneWidget,
    );
    // No folders on this page, so nothing to warn about.
    expect(find.textContaining('Folders on this page'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Share this vocabulary?'), findsNothing);
  });

  testWidgets('sharing a page with folders says they do not go, and where '
      'the whole setup is copied (ADR 0023)', (tester) async {
    final container = _container(boards: [_homeWithFolder(), _foodBoard()]);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor_share')));
    await tester.pumpAndSettle();
    expect(
      find.text('Folders on this page (like Food or People) are not '
          'included. To copy everything, use Settings, Copy to another '
          'device.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Share gives the share sheet an on-screen anchor (iPad requires one)',
      (tester) async {
    // iPad-sized screen: without a non-empty anchor the iPad share sheet
    // throws and the parent saw "Could not prepare this board to share".
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final tmp = Directory.systemTemp.createTempSync('share_anchor_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (_) async => tmp.path);
    Map<Object?, Object?>? shared;
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shared = call.arguments as Map<Object?, Object?>;
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
    });

    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor_share')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor_share_confirm')));
    for (var i = 0; i < 20 && shared == null; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(shared, isNotNull, reason: 'the share sheet was never asked');
    expect(find.text('Could not prepare this board to share.'), findsNothing);
    expect(shared!['originWidth'] as num, greaterThan(0));
    expect(shared!['originHeight'] as num, greaterThan(0));
    // The person who receives it gets instructions with the file
    // (clinical testing: in Messages the file alone only showed its text),
    // and a file name they can recognise.
    expect(shared!['text'] as String, contains('choose Lighthouse AAC'));
    expect(shared!['text'] as String, contains('Import a board pack'));
    final path = (shared!['paths'] as List).single as String;
    expect(path.split('/').last, startsWith('Lighthouse board - '));
    expect(path, endsWith('.json'));
  });

  testWidgets('long-press drag reorders words (insertion)', (tester) async {
    final container = _container();
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    // Drag btn_b (0,1) onto btn_a (0,0): insertion puts btn_b first.
    final from = tester.getCenter(find.byKey(const ValueKey('editor_tile_btn_b')));
    final to = tester.getCenter(find.byKey(const ValueKey('editor_tile_btn_a')));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600)); // long-press arm
    await g.moveTo(to);
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await tester.pumpAndSettle();

    final layout = container.read(boardLayoutProvider).valueOrNull;
    expect(layout?.positionOf('core_main', 'btn_b'), (row: 0, col: 0));
    expect(layout?.positionOf('core_main', 'btn_a'), (row: 0, col: 1));
  });
}
