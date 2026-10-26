/// The board editor's top bar and select-mode action bar fit every phone and
/// small tablet, in every language, at large system text. Uses the app's REAL
/// fonts: the default test font draws every glyph as a full em square, which
/// makes a long label like "Seleccionar" look ~40% wider than it is on a
/// device, so a layout check without real fonts reports false overflows (and
/// can hide real ones).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/theme/lighthouse_theme.dart';
import 'package:lighthouse/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_stores.dart';

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

final _board = AACBoard(
  schemaVersion: '1.3',
  boardId: 'core_main',
  boardName: 'Home Core',
  gridDimensions: (rows: 2, cols: 3),
  colorKey: const {'food': '#FFD9A6'},
  buttons: [_word('plain', 0, 0), _word('pinned', 0, 1)],
);

Future<void> _pumpEditor(
    WidgetTester tester, String lang, Size size, double scale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    editableBoardsProvider.overrideWith((ref) async => [_board]),
    ...fakeStoreOverrides(
      favourites:
          FakeFavStore([(boardId: 'core_main', buttonId: 'pinned')]),
    ),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
    child: UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildLighthouseTheme(
            fontFamily: lang == 'ar' ? 'Cairo' : 'Atkinson Hyperlegible'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale(lang)],
        locale: Locale(lang),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        // Pushed like the real editor, so the top bar has its back button.
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      const BoardEditScreen(rootBoardId: 'core_main'))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader('Atkinson Hyperlegible')
          ..addFont(rootBundle
              .load('assets/fonts/AtkinsonHyperlegible-Regular.ttf'))
          ..addFont(
              rootBundle.load('assets/fonts/AtkinsonHyperlegible-Bold.ttf')))
        .load();
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo.ttf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'tip_seen.editor': true,
      }));

  // 320 = smallest iOS 15 iPhone, 375/390/430 = current iPhones, 744 = iPad
  // mini (the scrolling small-tablet tier).
  const widths = [320.0, 375.0, 390.0, 430.0, 744.0];
  const scales = [1.0, 1.3, 2.0, 3.0];
  for (final lang in const ['en', 'es', 'ar']) {
    for (final w in widths) {
      for (final scale in scales) {
        testWidgets('$lang ${w.toInt()}pt text x$scale: bars fit',
            (tester) async {
          await _pumpEditor(tester, lang, Size(w, 820), scale);
          expect(tester.takeException(), isNull, reason: 'arrange top bar');

          // Select mode with the PINNED word chosen: the longest labels
          // ("Unpin" / "Remove from favourites").
          await tester.tap(find.byKey(const ValueKey('editor_select')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('editor_tile_pinned')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'select mode bars');
          final hide = find.byKey(const ValueKey('editor_bulk_hide'));
          expect(tester.getRect(hide).right, lessThanOrEqualTo(w),
              reason: 'Hide must be fully on screen');

          await tester.tap(find.byKey(const ValueKey('editor_selcancel')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('editor_add')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '+ Add top bar');
        });
      }
    }
  }

  testWidgets('phone select bar: short labels, and both actions still work',
      (tester) async {
    await _pumpEditor(tester, 'en', const Size(375, 820), 1.0);
    await tester.tap(find.byKey(const ValueKey('editor_select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor_tile_plain')));
    await tester.pumpAndSettle();
    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor_bulk_hide')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(BoardEditScreen)));
    expect(
        container
            .read(hiddenTilesProvider)
            .valueOrNull
            ?.isHidden('core_main', 'plain'),
        isTrue);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
