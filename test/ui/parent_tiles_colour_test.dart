/// Tile colour on screen (ADR 0022): the picker, and a chosen colour showing
/// on every tile surface (board tile, favourites strip). A built-in tile keeps
/// its category colour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/aac_button_tile.dart';
import 'package:lighthouse/ui/favourites_strip.dart';
import 'package:lighthouse/ui/widgets/tile_color_picker.dart';

AACButton _btn({String category = 'food', TileColor? color}) => AACButton(
      id: 'x',
      label: 'Pizza',
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: category,
      baseWeight: 0.5,
      iconUri: '',
      voiceOut: 'pizza',
      tileColor: color,
    );

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('es'), Locale('ar')],
      locale: locale,
      home: Scaffold(body: Center(child: child)),
    );

Color _tileFill(WidgetTester tester) => tester
    .widget<Material>(find.descendant(
      of: find.byType(AACButtonTile),
      matching: find.byType(Material),
    ).first)
    .color!;

void main() {
  group('TileColorPicker', () {
    testWidgets('shows grey + the six colours; tapping one reports it',
        (tester) async {
      TileColor? picked = TileColor.orange;
      var calls = 0;
      await tester.pumpWidget(_app(StatefulBuilder(
        builder: (context, setState) => TileColorPicker(
          value: picked,
          onChanged: (c) => setState(() {
            picked = c;
            calls++;
          }),
        ),
      )));
      expect(find.byKey(const ValueKey('tile_color_grey')), findsOneWidget);
      for (final c in TileColor.values) {
        expect(find.byKey(ValueKey('tile_color_${c.name}')), findsOneWidget);
      }
      // The chosen colour's meaning is spelled out, not colour-only.
      expect(find.text('Orange: things, food, and places'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tile_color_green')));
      await tester.pump();
      expect(picked, TileColor.green);
      expect(find.text('Green: action words'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tile_color_grey')));
      await tester.pump();
      expect(picked, isNull);
      expect(find.text('Grey: no colour group'), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('each swatch is a labelled, selectable button for screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(TileColorPicker(
        value: TileColor.blue,
        onChanged: (_) {},
      )));
      expect(
        tester.getSemantics(find.byKey(const ValueKey('tile_color_blue'))),
        matchesSemantics(
          label: 'Blue: feelings and yes or no',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('tile_color_pink'))),
        matchesSemantics(
          label: 'Pink: social words and urgent needs',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('swatches are at least 48 x 48', (tester) async {
      await tester.pumpWidget(_app(TileColorPicker(value: null, onChanged: (_) {})));
      final size = tester.getSize(find.byKey(const ValueKey('tile_color_green')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    for (final locale in const [Locale('es'), Locale('ar')]) {
      testWidgets('${locale.languageCode}: names are translated and fit at a '
          'phone width with large text', (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 640), textScaler: TextScaler.linear(2.0)),
          child: _app(
            const Padding(
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: TileColorPicker(value: TileColor.purple, onChanged: _noop),
              ),
            ),
            locale: locale,
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(
            find.text(locale.languageCode == 'es'
                ? 'Morado: preguntas y tiempo'
                : 'بنفسجي: الأسئلة والوقت'),
            findsOneWidget);
      });
    }
  });

  group('a chosen colour shows on every tile surface', () {
    testWidgets('board tile: the chosen colour wins over the category',
        (tester) async {
      await tester.pumpWidget(_app(SizedBox(
        width: 120,
        height: 120,
        child: AACButtonTile(
          button: _btn(category: kCustomCategory, color: TileColor.green),
          colorKey: const {'food': '#FFD9A6'},
          onTap: () {},
        ),
      )));
      expect(_tileFill(tester), const Color(0xFFC2FFC2));
    });

    testWidgets('board tile: no colour = category colour (unchanged)',
        (tester) async {
      await tester.pumpWidget(_app(SizedBox(
        width: 120,
        height: 120,
        child: AACButtonTile(
          button: _btn(),
          colorKey: const {'food': '#FFD9A6'},
          onTap: () {},
        ),
      )));
      expect(_tileFill(tester), const Color(0xFFFFD9A6));
    });

    testWidgets('board tile: a parent-made tile with no colour stays grey',
        (tester) async {
      await tester.pumpWidget(_app(SizedBox(
        width: 120,
        height: 120,
        child: AACButtonTile(
          button: _btn(category: kCustomCategory),
          colorKey: const {'food': '#FFD9A6'},
          onTap: () {},
        ),
      )));
      expect(_tileFill(tester), AACButtonTile.fallbackColor);
    });

    testWidgets('favourites strip uses the chosen colour too', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          homeFavouritesProvider.overrideWith((ref) async =>
              [_btn(category: kCustomCategory, color: TileColor.purple)]),
        ],
        child: _app(FavouritesStrip(
          onTap: (_) {},
          colorKey: const {'food': '#FFD9A6'},
        )),
      ));
      await tester.pumpAndSettle();
      final material = tester.widget<Material>(find
          .descendant(
              of: find.byType(FavouritesStrip), matching: find.byType(Material))
          .first);
      expect(material.color, const Color(0xFFE6A6FF));
    });
  });
}

void _noop(TileColor? _) {}
