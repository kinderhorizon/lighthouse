/// Multilingual Speech Synthesis & Locale Fallback Verification Tests.
///
/// Verifies:
/// 1. Multilingual voice tag negotiation across all 4 production locales:
///    - German (`de`)
///    - Modern Standard Arabic (`ar`)
///    - Algerian Darija (`ar_dz` -> `ar-DZ`)
///    - English (`en`)
/// 2. Dialect fallback ladder for Algerian Darija:
///    - Exact dialect `ar-DZ` -> Base `ar` -> Standard voice fallback (`ar-SA`, `ar-XA`, `ara`).
/// 3. Speech parameter clamping:
///    - Volume clamped to [0.0, 1.0].
///    - Speech Rate clamped to [0.1, 2.0].
///    - Pitch clamped to [0.5, 2.0].
/// 4. Sentence sequencing:
///    - Sequence synthesis concatenates tokens with single spaces (`texts.join(' ')`)
///      preserving Arabic & Darija prosodic cadence.
///    - Empty / blank tokens are ignored without unnecessary platform invocations.
/// 5. Fault tolerance:
///    - Missing voices or platform channel exceptions fail closed gracefully without crashes.
/// 6. FallbackTTSEngine composite generation supersession:
///    - Generation tokens abort stale in-flight token playback on newer user taps or stop calls.
library;

import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/tts/fallback_tts_engine.dart';
import 'package:lighthouse/services/tts/system_tts_engine.dart';
import 'package:lighthouse/services/tts/tts_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SystemTTSEngine Multilingual & Fallback Verification', () {
    const channel = MethodChannel('flutter_tts');
    final List<MethodCall> methodCalls = [];
    final List<String> availableLanguages = ['en-US', 'de-DE', 'ar-SA'];
    int setLanguageResult = 1;

    setUp(() {
      methodCalls.clear();
      availableLanguages.clear();
      availableLanguages.addAll(['en-US', 'de-DE', 'ar-SA']);
      setLanguageResult = 1;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'getLanguages':
            return availableLanguages;
          case 'setLanguage':
            return setLanguageResult;
          case 'speak':
            return 1;
          case 'stop':
            return 1;
          case 'setVolume':
            return 1;
          case 'setSpeechRate':
            return 1;
          case 'setPitch':
            return 1;
          case 'awaitSpeakCompletion':
            return 1;
          case 'setQueueMode':
            return 1;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('1. Configures English (en) and German (de) locales correctly', () async {
      final engine = SystemTTSEngine();

      await engine.speak('Hello world', locale: const Locale('en'));
      final enCalls = methodCalls.where((c) => c.method == 'setLanguage').toList();
      expect(enCalls, isNotEmpty);
      expect(enCalls.last.arguments, equals('en'));

      methodCalls.clear();
      await engine.speak('Guten Tag', locale: const Locale('de'));
      final deCalls = methodCalls.where((c) => c.method == 'setLanguage').toList();
      expect(deCalls, isNotEmpty);
      expect(deCalls.last.arguments, equals('de'));
    });

    test('2. Algerian Darija (ar-DZ) falls back gracefully to ar-SA when ar-DZ unavailable', () async {
      final engine = SystemTTSEngine();

      // Simulate device where setLanguage('ar-DZ') returns 0 (unsupported),
      // base 'ar' returns 0, but available languages has 'ar-SA'
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        methodCalls.add(call);
        if (call.method == 'getLanguages') {
          return ['en-US', 'de-DE', 'ar-SA'];
        }
        if (call.method == 'setLanguage') {
          final lang = call.arguments as String;
          if (lang == 'ar-DZ' || lang == 'ar') return 0;
          if (lang == 'ar-SA') return 1;
        }
        return 1;
      });

      await engine.speak('صحا خويا', locale: const Locale('ar', 'DZ'));

      final langCalls = methodCalls.where((c) => c.method == 'setLanguage').toList();
      expect(langCalls.map((c) => c.arguments), contains('ar-DZ'));
      expect(langCalls.map((c) => c.arguments), contains('ar'));
      expect(langCalls.map((c) => c.arguments), contains('ar-SA'));
    });

    test('3. Speech parameters (volume, rate, pitch) are clamped within safe bounds', () async {
      final engine = SystemTTSEngine();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      methodCalls.clear();

      // Volume: [0.0, 1.0]
      await engine.setVolume(1.8);
      expect(methodCalls.last.method, equals('setVolume'));
      expect(methodCalls.last.arguments, equals(1.0));

      await engine.setVolume(-0.5);
      expect(methodCalls.last.method, equals('setVolume'));
      expect(methodCalls.last.arguments, equals(0.0));

      // Rate: [0.1, 2.0]
      await engine.setRate(3.5);
      expect(methodCalls.last.method, equals('setSpeechRate'));
      expect(methodCalls.last.arguments, equals(2.0));

      await engine.setRate(0.01);
      expect(methodCalls.last.method, equals('setSpeechRate'));
      expect(methodCalls.last.arguments, equals(0.1));

      // Pitch: [0.5, 2.0]
      await engine.setPitch(4.0);
      expect(methodCalls.last.method, equals('setPitch'));
      expect(methodCalls.last.arguments, equals(2.0));

      await engine.setPitch(0.1);
      expect(methodCalls.last.method, equals('setPitch'));
      expect(methodCalls.last.arguments, equals(0.5));
    });

    test('4. Sequence synthesis produces continuous prosody with single utterance', () async {
      final engine = SystemTTSEngine();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      methodCalls.clear();

      await engine.speakSequence(['أنا', 'أريد', 'الماء'], locale: const Locale('ar'));

      final speakCalls = methodCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls.length, equals(1));
      final spoken = speakCalls.first.arguments;
      if (spoken is Map) {
        expect(spoken['text'], equals('أنا أريد الماء'));
      } else {
        expect(spoken, equals('أنا أريد الماء'));
      }
    });

    test('5. Empty or whitespace-only utterances do not trigger speak', () async {
      final engine = SystemTTSEngine();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      methodCalls.clear();

      await engine.speak('   ', locale: const Locale('en'));
      await engine.speakSequence(['', '  '], locale: const Locale('de'));

      final speakCalls = methodCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls, isEmpty);
    });

    test('6. Graceful failure on platform channel exceptions without throwing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'TTS_FAILURE', message: 'Audio service disconnected');
      });

      final engine = SystemTTSEngine();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Must not throw unhandled exceptions
      await expectLater(
        engine.speak('Test resilience', locale: const Locale('en')),
        completes,
      );
      await expectLater(
        engine.setVolume(0.8),
        completes,
      );
      await expectLater(
        engine.stop(),
        completes,
      );
    });
  });

  group('FallbackTTSEngine Generation Supersession & Cancellation', () {
    test('1. In-flight mixed sequence loop is aborted when stop() is called', () async {
      final engineA = _TokenAwareMockEngine('EngineA', {'Word1', 'Word3'});
      final engineB = _TokenAwareMockEngine('EngineB', {'Word2'});

      final fallback = FallbackTTSEngine([engineA, engineB]);
      final run = fallback.speakSequence(['Word1', 'Word2', 'Word3'], locale: const Locale('en'));

      // Allow Word1 to start playing on EngineA, then call stop()
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await fallback.stop();
      await run;

      // Word1 ran, but Word2 and Word3 were cancelled before dispatch
      expect(engineB.spoken, isEmpty);
      expect(engineA.spoken.contains('Word3'), isFalse);
    });

    test('2. In-flight sequence loop is superseded by newer sequence', () async {
      final engineA = _TokenAwareMockEngine('EngineA', {'FirstA', 'SecondA'});
      final engineB = _TokenAwareMockEngine('EngineB', {'InterleavedB'});

      final fallback = FallbackTTSEngine([engineA, engineB]);

      // Trigger first run: FirstA (EngineA) -> InterleavedB (EngineB) -> SecondA (EngineA)
      final firstRun = fallback.speakSequence(['FirstA', 'InterleavedB', 'SecondA'], locale: const Locale('en'));

      // Superseding run immediately fired
      final secondRun = fallback.speakSequence(['FirstA'], locale: const Locale('en'));

      await Future.wait([firstRun, secondRun]);

      // EngineB never played InterleavedB because supersession token was incremented
      expect(engineB.spoken, isEmpty);
    });
  });
}

class _TokenAwareMockEngine implements TTSEngine {
  _TokenAwareMockEngine(this.name, this.supportedTokens);

  final String name;
  final Set<String> supportedTokens;
  final List<String> spoken = [];

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async =>
      supportedTokens.contains(text);

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    spoken.add(text);
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    for (final t in texts) {
      spoken.add(t);
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}
}
