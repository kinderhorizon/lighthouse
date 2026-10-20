/// Algerian Darija (ar-DZ) localization and RTL widget tests.
library;

import 'dart:convert';
import 'dart:io';

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

ProviderScope _wrapWithDarijaLocale() {
  final crashStore = CrashLogStore(
    cacheDirOverride: Directory.systemTemp.createTempSync('darija_test_'),
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
    child: const _DarijaLighthouseApp(),
  );
}

class _DarijaLighthouseApp extends StatelessWidget {
  const _DarijaLighthouseApp();

  @override
  Widget build(BuildContext context) {
    const spec = LocaleSpec(
      code: 'ar_dz',
      direction: TextDirection.rtl,
      ttsStrategy: TtsStrategy.systemOnly,
      reviewStatus: ReviewStatus.provisional,
      englishName: 'Algerian Darija',
      nativeName: 'الدارجة الجزائرية',
      requiredFontFamily: 'Cairo',
    );
    return MaterialApp(
      locale: const Locale('ar', 'DZ'),
      supportedLocales: LocaleRegistry.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: spec.requiredFontFamily,
        fontFamilyFallback: const ['Cairo', 'AtkinsonHyperlegible'],
      ),
      home: const LighthouseAppRoot(),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (tester.any(find.byType(AACGrid))) return;
  }
  throw StateError('Grid did not render under Darija locale');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    final raw = File('boards/core_main.json').readAsStringSync();
    _fixtureBoard = AACBoard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding.completed': true,
    });
  });

  test('Darija locale spec is registered with RTL and Cairo font', () {
    final spec = LocaleRegistry.specForCode('ar_dz');
    expect(spec, isNotNull);
    expect(spec!.direction, TextDirection.rtl);
    expect(spec.isRtl, isTrue);
    expect(spec.requiredFontFamily, 'Cairo');
    expect(spec.locale, const Locale('ar', 'DZ'));
  });

  testWidgets('Algerian Darija forces RTL directionality on AAC grid',
      (tester) async {
    await tester.pumpWidget(_wrapWithDarijaLocale());
    await _settle(tester);

    final gridContext = tester.element(find.byType(AACGrid));
    expect(Directionality.of(gridContext), TextDirection.rtl);
  });

  testWidgets('Algerian Darija renders authentic Darija labels', (tester) async {
    await tester.pumpWidget(_wrapWithDarijaLocale());
    await _settle(tester);

    // Verify key Darija words render
    expect(find.text('أنا'), findsOneWidget);
    expect(find.text('حاب'), findsOneWidget);
    expect(find.text('الما'), findsOneWidget);
    expect(find.text('راني جيعان'), findsOneWidget);
    expect(find.text('راني تعبان'), findsOneWidget);
    expect(find.text('عاونّي من فضلك'), findsOneWidget);
    expect(find.text('واش هذا؟'), findsOneWidget);
  });

  test('All required Algerian Darija practical phrases exist in boards', () {
    final files = Directory('boards')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));

    final allVoiceOuts = <String>{};
    final allLabels = <String>{};

    for (final f in files) {
      final b = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final btn in (b['buttons'] as List).cast<Map<String, dynamic>>()) {
        if (btn['voice_out_ar_dz'] != null) {
          allVoiceOuts.add(btn['voice_out_ar_dz'] as String);
        }
        if (btn['label_ar_dz'] != null) {
          allLabels.add(btn['label_ar_dz'] as String);
        }
      }
    }

    final requiredPhrases = [
      'راني جيعان',
      'حاب نشرب الماء',
      'حاب ناكل',
      'راني تعبان',
      'عاونّي من فضلك',
      'ما فهمتش',
      'حاب نروح للدار',
      'واش هذا؟',
      'راني فرحان',
    ];

    for (final phrase in requiredPhrases) {
      final found = allVoiceOuts.contains(phrase) || allLabels.contains(phrase);
      expect(found, isTrue, reason: 'Missing required Darija phrase: "$phrase"');
    }
  });
}
