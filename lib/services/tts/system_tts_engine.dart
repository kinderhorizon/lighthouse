/// System TTS implementation.
///
/// Wraps the `flutter_tts` package, which in turn wraps iOS
/// AVSpeechSynthesizer and Android TextToSpeech. Acceptable-to-good quality
/// across the alpha device/locale matrix (iPad + Galaxy Tab x en/ar/es).
/// See docs/adr/0004-tts-strategy.md.
library;

import 'dart:ui';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

class SystemTTSEngine implements TTSEngine {
  SystemTTSEngine() : _backend = FlutterTts() {
    // Make speak() resolve only when the utterance finishes, not when it is
    // merely dispatched. The sentence replay routes tokens one at a time and
    // awaits each (ADR 0010); without this, a system-voice token (e.g. the
    // English "to" connector with no bundled clip) would return immediately and
    // overlap the next bundled clip.
    _backend.awaitSpeakCompletion(true);
  }

  final FlutterTts _backend;
  String? _currentLanguageTag;

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    final tag = _bcp47Tag(locale);
    if (tag != _currentLanguageTag) {
      await _backend.setLanguage(tag);
      _currentLanguageTag = tag;
    }
    // Latest-wins: stop any in-flight utterance before starting this one.
    // We set awaitSpeakCompletion(true) above, and flutter_tts 4.2.5's Android
    // plugin DISCARDS a speak() that arrives while a previous awaited utterance
    // is still speaking (its "speak" handler returns success(0) and plays
    // nothing). So a child tapping a second system-voice tile (a custom button
    // with no recording, or any word with no bundled clip) before the first
    // finished would hear silence, with the tile still animating: a silent
    // failure. Calling stop() first clears the in-flight utterance AND resolves
    // its pending future (the plugin's "stop" handler completes speakResult),
    // so this tap always speaks. This mirrors the supersede-on-tap behavior the
    // bundled engine already has (BundledAudioTTSEngine, via its generation
    // token) and the custom-recording path in main._speakSafely. See ADR 0004
    // and ADR 0010.
    await _backend.stop();
    await _backend.speak(text);
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    // System TTS is text-agnostic, so the whole sentence is one synthesized
    // utterance (which also gives natural prosody). Used only when no bundled
    // clip covers a token (ADR 0010).
    await speak(texts.join(' '), locale: locale);
  }

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async {
    // System TTS is text-agnostic: it can speak anything the OS has a voice
    // for in this locale.
    final available = await _backend.getLanguages;
    if (available is! List) return false;
    final tag = _bcp47Tag(locale).toLowerCase();
    final lang = locale.languageCode.toLowerCase();
    for (final entry in available) {
      final tagOnPlatform = entry?.toString().toLowerCase() ?? '';
      if (tagOnPlatform == tag) return true;
      if (tagOnPlatform.startsWith('$lang-') || tagOnPlatform == lang) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> stop() async {
    await _backend.stop();
  }

  @override
  Future<void> dispose() async {
    await _backend.stop();
  }

  static String _bcp47Tag(Locale locale) {
    final lang = locale.languageCode;
    final region = locale.countryCode;
    return region == null || region.isEmpty ? lang : '$lang-$region';
  }
}
