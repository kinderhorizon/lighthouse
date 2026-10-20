/// Composite TTS engine.
///
/// Delegates to a priority-ordered list of engines. For each [speak] call it
/// walks the list and uses the first engine whose [canSpeak] returns true for
/// THAT text in the requested locale. If none can, it falls back to the last
/// engine in the list (typically [SystemTTSEngine]) so something is attempted
/// rather than nothing.
///
/// Because [canSpeak] is per-utterance, a bundled-clip engine placed first
/// handles tapped core vocabulary (a clip exists) while free-typed text in the
/// same locale falls through to system TTS automatically. Wiring is:
///   FallbackTTSEngine([BundledAudioTTSEngine(...), SystemTTSEngine()])
library;

import 'dart:ui';

import 'tts_engine.dart';

class FallbackTTSEngine implements TTSEngine {
  FallbackTTSEngine(List<TTSEngine> engines)
      : assert(engines.isNotEmpty, 'FallbackTTSEngine needs at least one engine'),
        _engines = List.unmodifiable(engines);

  final List<TTSEngine> _engines;

  /// Monotonic supersession token for THIS composite (mirrors the per-player
  /// tokens in [BundledAudioTTSEngine] / [CustomVoicePlayer]). [stop] and every
  /// fresh [speakSequence] bump it; the mixed per-token loop below checks it
  /// between tokens and bails the instant a newer request (a child's tap calling
  /// [stop], or a fresh replay) supersedes this one. Without this, the loop has
  /// no abort hook: a tap landing mid-replay would be silenced by the loop's
  /// next stop-then-speak, then the stale token would play (P0-2 interleaving B).
  int _generation = 0;

  Future<TTSEngine> _pickFor(String text, Locale locale) async {
    for (final e in _engines) {
      if (await e.canSpeak(text, locale: locale)) return e;
    }
    return _engines.last;
  }

  @override
  Future<void> setVolume(double volume) async {
    for (final e in _engines) {
      await e.setVolume(volume);
    }
  }

  @override
  Future<void> setRate(double rate) async {
    for (final e in _engines) {
      await e.setRate(rate);
    }
  }

  @override
  Future<void> setPitch(double pitch) async {
    for (final e in _engines) {
      await e.setPitch(pitch);
    }
  }

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    final engine = await _pickFor(text, locale);
    await engine.speak(text, locale: locale);
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    if (texts.isEmpty) return;
    final gen = ++_generation; // claim; supersedes any in-flight sequence

    List<String> currentRun = [];
    TTSEngine? currentEngine;

    for (final t in texts) {
      if (gen != _generation) return;
      final engine = await _pickFor(t, locale);
      if (gen != _generation) return;

      if (engine == currentEngine) {
        currentRun.add(t);
      } else {
        if (currentEngine != null && currentRun.isNotEmpty) {
          await currentEngine.speakSequence(currentRun, locale: locale);
        }
        currentEngine = engine;
        currentRun = [t];
      }
    }

    if (gen == _generation && currentEngine != null && currentRun.isNotEmpty) {
      await currentEngine.speakSequence(currentRun, locale: locale);
    }
  }

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async {
    for (final e in _engines) {
      if (await e.canSpeak(text, locale: locale)) return true;
    }
    return false;
  }

  @override
  Future<void> stop() async {
    ++_generation; // abort any in-flight mixed per-token loop (P0-2)
    for (final e in _engines) {
      await e.stop();
    }
  }

  @override
  Future<void> dispose() async {
    for (final e in _engines) {
      await e.dispose();
    }
  }
}
