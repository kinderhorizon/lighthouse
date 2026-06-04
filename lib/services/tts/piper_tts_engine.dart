/// Piper TTS placeholder.
///
/// Stub for Phase 2 (bundled neural TTS for locales where system TTS quality
/// is weak). Always returns false from [supports], so [FallbackTTSEngine]
/// skips it and falls through to [SystemTTSEngine]. The real implementation
/// integrates Piper native bindings, voice caching (20-60 MB per voice),
/// and locale-to-voice mapping. See docs/adr/0004-tts-strategy.md.
library;

import 'dart:ui';

import 'tts_engine.dart';

class PiperTTSEngine implements TTSEngine {
  const PiperTTSEngine();

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    throw UnimplementedError(
      'PiperTTSEngine is a Phase 2 placeholder. Use SystemTTSEngine.',
    );
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    throw UnimplementedError(
      'PiperTTSEngine is a Phase 2 placeholder. Use SystemTTSEngine.',
    );
  }

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async => false;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
