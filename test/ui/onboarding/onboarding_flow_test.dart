import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lighthouse/main.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';

class _RecordingTTSEngine implements TTSEngine {
  final List<String> spoken = [];
  @override
  Future<void> speak(String text, {required Locale locale}) async {
    spoken.add(text);
  }
  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    spoken.add(texts.join(' '));
  }
  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async => true;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

late final AACBoard _fixtureBoard;

ProviderScope _wrap({List<Override> extras = const []}) {
  final crashStore = CrashLogStore(
    cacheDirOverride: Directory.systemTemp.createTempSync('onb_flow_test_'),
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
      ...extras,
    ],
    child: const LighthouseApp(),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (tester.any(find.byType(OnboardingFlow)) ||
        tester.any(find.text('Help'))) {
      return;
    }
  }
  throw StateError('App did not settle into onboarding or board');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _fixtureBoard = AACBoard.fromJson(
    jsonDecode(File('test/fixtures/core_main.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  group('Onboarding flow gates the board', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('First launch shows OnboardingFlow, not the board',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap());
      await _settle(tester);
      expect(find.byType(OnboardingFlow), findsOneWidget);
      expect(find.text('Help'), findsNothing);
    });

    testWidgets('Already-completed flag skips straight to the board',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding.completed': true,
      });
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap());
      await _settle(tester);
      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.text('Help'), findsOneWidget);
    });
  });

  group('Onboarding navigation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('Done from screen 1 immediately marks completed',
        (tester) async {
      final fakeTts = _RecordingTTSEngine();
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(extras: [
        ttsEngineProvider.overrideWith((ref) => fakeTts),
      ]));
      await _settle(tester);

      // Done is available on the FIRST screen (ADR 0003 § Onboarding: a parent
      // can finish from anywhere). Tap it without advancing and the board
      // appears.
      expect(find.byType(OnboardingFlow), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await _settle(tester);

      expect(find.byType(OnboardingFlow), findsNothing);
      expect(find.text('Help'), findsOneWidget);
    });

    testWidgets('Selecting a Q2 home label persists', (tester) async {
      final container = ProviderContainer(overrides: [
        defaultBoardProvider.overrideWith((ref) async => _fixtureBoard),
      ]);
      addTearDown(container.dispose);

      // Drive the notifier directly so we cleanly test persistence
      // without fighting the PageView's scroll mechanics.
      await container.read(onboardingNotifierProvider.future);
      await container
          .read(onboardingNotifierProvider.notifier)
          .setHomeLabel(OnboardingHomeLabel.school);

      final state = await OnboardingRepository().read();
      expect(state.homeLabel, OnboardingHomeLabel.school);
    });
  });

  group('Wi-Fi-context step is platform-gated (ADR 0016)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    // PageView builds pages lazily, so we navigate rather than search offstage.
    Future<void> next(WidgetTester tester) async {
      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('shown when the platform uses Wi-Fi context (Android)',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(extras: [
        wifiSourceProvider
            .overrideWith((ref) => StubWifiSource(usesWifiContext: true)),
      ]));
      await _settle(tester);
      // grid (0) -> place (1) -> wifi (2)
      await next(tester);
      await next(tester);
      expect(find.text('Learn words for each place'), findsOneWidget);
    });

    testWidgets('omitted when the platform does not read Wi-Fi context (iOS)',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(extras: [
        wifiSourceProvider
            .overrideWith((ref) => StubWifiSource(usesWifiContext: false)),
      ]));
      await _settle(tester);
      // Walk the whole flow (grid -> place -> privacy); the step never appears.
      expect(find.text('Learn words for each place'), findsNothing);
      await next(tester);
      await next(tester);
      expect(find.text('Learn words for each place'), findsNothing);
    });
  });
}
