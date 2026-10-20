/// System TTS implementation.
///
/// Wraps the `flutter_tts` package, which in turn wraps iOS
/// AVSpeechSynthesizer and Android TextToSpeech. Acceptable-to-good quality
/// across the alpha device/locale matrix (iPad + Galaxy Tab x en/ar/es).
/// See docs/adr/0004-tts-strategy.md.
library;

import 'dart:io';
import 'dart:ui';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

class SystemTTSEngine implements TTSEngine {
  SystemTTSEngine() : _backend = FlutterTts() {
    _initEngine();
  }

  final FlutterTts _backend;
  String? _currentLanguageTag;
  double _volume = 1.0;
  double _rate = 1.0;
  double _pitch = 1.0;

  Future<void> _initEngine() async {
    try {
      await _backend.awaitSpeakCompletion(true);
      if (Platform.isIOS) {
        await _backend.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
        await _backend.setSharedInstance(true);
      }
      if (Platform.isAndroid) {
        await _backend.setQueueMode(0); // flush mode: latest utterance wins
      }
      await _backend.setVolume(_volume);
      await _backend.setSpeechRate(_rate);
      await _backend.setPitch(_pitch);
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _backend.setVolume(_volume);
    } catch (_) {}
  }

  @override
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.1, 2.0);
    try {
      await _backend.setSpeechRate(_rate);
    } catch (_) {}
  }

  @override
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    try {
      await _backend.setPitch(_pitch);
    } catch (_) {}
  }

  /// Returns true if an exact dialect voice (e.g. ar-DZ) exists on device,
  /// or false when falling back to a general base voice (e.g. ar).
  Future<bool> hasExactVoiceFor(Locale locale) async {
    try {
      final available = await _backend.getLanguages;
      if (available is! List) return false;
      final tag = _bcp47Tag(locale).toLowerCase();
      for (final entry in available) {
        if (entry?.toString().toLowerCase() == tag) return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _configureLanguage(Locale locale) async {
    final tag = _bcp47Tag(locale);
    try {
      // 1. Try exact requested tag (e.g., 'ar-DZ', 'de-DE', 'en-US')
      final res = await _backend.setLanguage(tag);
      if (res == 1) {
        _currentLanguageTag = tag;
        return;
      }
      // 2. If dialect failed, try base language code (e.g., 'ar', 'de', 'en')
      if (locale.countryCode != null) {
        final baseRes = await _backend.setLanguage(locale.languageCode);
        if (baseRes == 1) {
          _currentLanguageTag = locale.languageCode;
          return;
        }
      }
      // 3. For Arabic, search available voices for standard Arabic fallback (e.g. ar-XA, ar-SA, ara)
      if (locale.languageCode == 'ar') {
        final available = await _backend.getLanguages;
        if (available is List) {
          for (final entry in available) {
            final entryStr = entry?.toString().toLowerCase() ?? '';
            if (entryStr.startsWith('ar') || entryStr.startsWith('ara')) {
              await _backend.setLanguage(entry.toString());
              _currentLanguageTag = entry.toString();
              return;
            }
          }
        }
      }
      _currentLanguageTag = tag;
    } catch (_) {
      _currentLanguageTag = tag;
    }
  }

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    if (text.trim().isEmpty) return;
    try {
      final tag = _bcp47Tag(locale);
      if (tag != _currentLanguageTag) {
        await _configureLanguage(locale);
      }
      // Latest-wins: stop any in-flight utterance before starting this one.
      await _backend.stop();
      await _backend.speak(text);
    } catch (_) {}
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    // Speak full sentence as ONE single continuous synthesized utterance.
    // Provides natural Arabic and Algerian Darija prosody, smooth rhythm,
    // and zero inter-word pause without repeated engine initialization.
    final sentence = texts.join(' ').trim();
    if (sentence.isNotEmpty) {
      await speak(sentence, locale: locale);
    }
  }

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async {
    // System TTS is text-agnostic: it can speak anything the OS has a voice
    // for in this locale.
    try {
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
    } catch (_) {}
    return false;
  }

  @override
  Future<void> stop() async {
    try {
      await _backend.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _backend.stop();
    } catch (_) {}
  }

  static String _bcp47Tag(Locale locale) {
    final lang = locale.languageCode;
    final region = locale.countryCode;
    return region == null || region.isEmpty ? lang : '$lang-$region';
  }
}
