/// RTL + Arabic-locale widget tests.
///
/// Validates that when the device locale is Arabic, the app:
/// 1. propagates TextDirection.rtl through the widget tree
/// 2. renders all 56 tiles with their Arabic labels (no English leak)
/// 3. mirrors the folder-tile border radius (Directional shape, not LTR)
/// 4. shows the localized board name in the AppBar (not the English default)
/// 5. resolves the bundled Cairo font for Arabic text (requiredFontFamily)
///
/// The harness pins MaterialApp.locale to ar and mirrors main.dart's theme
/// (including the registry-driven fontFamily + Cairo fallback) so rendering
/// matches production. This is the desk half of the on-device Arabic pass;
/// the device eyeball (glyph crispness at tile size, real RTL layout) still
/// happens on hardware.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lighthouse/i18n/locale_registry.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/main.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';

late final AACBoard _fixtureBoard;

ProviderScope _wrapWithArabicLocale() {
  final crashStore = CrashLogStore(
    cacheDirOverride: Directory.systemTemp.createTempSync('rtl_test_'),
  );
  final capture = CrashCapture(
    store: crashStore,
    deviceInfoSource: DeviceInfoSource(),
  );
  return ProviderScope(
    overrides: [
      defaultBoardProvider.overrideWith((ref) async => _fixtureBoard),
      crashLogStoreProvider.overrideWithValue(crashStore),
      crashCaptureProvider.overrideWithValue(capture),
    ],
    // Avoid Localizations.override (which requires an ancestor Localizations
    // scope, not present before MaterialApp builds). Instead, force the
    // MaterialApp's locale directly via the locale parameter, which feeds
    // GlobalMaterialLocalizations and propagates Directionality from the
    // chosen locale.
    child: const _ArabicLighthouseApp(),
  );
}

class _ArabicLighthouseApp extends StatelessWidget {
  const _ArabicLighthouseApp();

  @override
  Widget build(BuildContext context) {
    // Build the same tree LighthouseApp builds, with locale pinned to ar.
    // Kept in sync with main.dart by sharing the inner Scaffold via the
    // production _BoardScreen exported from main.dart.
    // Mirror main.dart's theme exactly, including the registry-driven font
    // (ar -> Cairo) and the app-wide Cairo fallback. Keep in sync with
    // LighthouseApp.build.
    final fontFamily = LocaleRegistry.specForCode('ar')?.requiredFontFamily;
    return MaterialApp(
      title: 'Lighthouse AAC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE8873C)),
        useMaterial3: true,
        fontFamily: fontFamily,
        fontFamilyFallback: const ['Cairo'],
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('es'),
      ],
      locale: const Locale('ar'),
      home: const LighthouseAppRoot(),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  // Pin a large-tablet surface so the board uses the fill layout and builds all
  // 56 tiles (the default 800x600 surface now falls in the small-tablet scroll
  // tier, which lazy-builds offscreen tiles). See widget_test.dart.
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (tester.any(find.byType(AACGrid))) return;
  }
  throw StateError('Grid did not render under Arabic locale');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _fixtureBoard = AACBoard.fromJson(
    jsonDecode(File('test/fixtures/core_main.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding.completed': true,
    });
  });

  testWidgets('Arabic locale forces RTL on the grid surface',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithArabicLocale());
    await _settle(tester);

    final gridContext = tester.element(find.byType(AACGrid));
    expect(Directionality.of(gridContext), TextDirection.rtl);
  });

  testWidgets('All 56 buttons still render under Arabic locale',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithArabicLocale());
    await _settle(tester);

    // Arabic labels now ship in the board (label_ar), so tiles render their
    // localized label, not the English fallback. (btn_i -> أنا, btn_help ->
    // مساعدة, btn_bathroom -> الحمّام, btn_food_folder -> طعام.)
    expect(find.text('أنا'), findsOneWidget);
    expect(find.text('مساعدة'), findsOneWidget);
    expect(find.text('الحمّام'), findsOneWidget);
    expect(find.text('طعام'), findsOneWidget);
    // English labels must NOT leak through once a translation exists.
    expect(find.text('Help'), findsNothing);
    expect(find.byType(AACButtonTile), findsNWidgets(56));
  });

  testWidgets('Folder affordance badge mirrors in RTL (PositionedDirectional)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithArabicLocale());
    await _settle(tester);

    final foodTileFinder = find.ancestor(
      of: find.text('طعام'),
      matching: find.byType(Material),
    );
    expect(foodTileFinder, findsWidgets);

    // The folder "more" affordance (alpha feedback #1/#4) sits in the
    // top-trailing corner via PositionedDirectional, so it mirrors to the
    // top-leading corner automatically under RTL. Asserting the directional
    // widget is present is the load-bearing property: don't hardcode an LTR
    // corner for the affordance.
    expect(
      find.descendant(
        of: foodTileFinder.first,
        matching: find.byType(PositionedDirectional),
      ),
      findsOneWidget,
      reason: 'Folder tile must place its affordance badge directionally so '
          'it mirrors automatically in Arabic / Urdu / Hebrew locales.',
    );
  });

  testWidgets('AppBar shows the localized board name, not the English default',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithArabicLocale());
    await _settle(tester);

    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('الرئيسية'), // board_name_ar for the home board
    );
    expect(appBarTitle, findsOneWidget,
        reason: 'the board title must use boardNameFor(locale), so an Arabic '
            'family sees the Arabic name rather than "Home Core".');
    expect(find.text('Home Core'), findsNothing);
  });

  testWidgets('Arabic text resolves the bundled Cairo font (requiredFontFamily)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithArabicLocale());
    await _settle(tester);

    final gridContext = tester.element(find.byType(AACGrid));
    final theme = Theme.of(gridContext);
    // ar's requiredFontFamily flows into ThemeData.fontFamily, so the resolved
    // text theme uses Cairo (the bundled face), never the platform default.
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Cairo');
    expect(theme.textTheme.titleLarge?.fontFamily, 'Cairo');
  });
}
