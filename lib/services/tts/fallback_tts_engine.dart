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

  Future<TTSEngine> _pickFor(String text, Locale locale) async {
    for (final e in _engines) {
      if (await e.canSpeak(text, locale: locale)) return e;
    }
    return _engines.last;
  }

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    final engine = await _pickFor(text, locale);
    await engine.speak(text, locale: locale);
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    if (texts.isEmpty) return;
    // Walk engines in priority order looking for ONE that covers every token,
    // so it can play the whole list gaplessly (the bundled engine concatenates
    // its clips into a single playlist; removes the per-word reload gaps that
    // made the replay slow/choppy, clinical review). But do NOT let a lower-
    // priority engine swallow tokens a higher one could speak: the system
    // engine is text-agnostic ("covers all" always), so if a higher-priority
    // engine covers SOME but not all, stop and route per-token instead, keeping
    // its tokens on the warm voice (that all-or-nothing fallback was the #1
    // voice-switch bug). Common English case: bundled covers all (incl the "to"
    // connector) -> one gapless warm playlist.
    for (final e in _engines) {
      var coversAll = true;
      var coversAny = false;
      for (final t in texts) {
        if (await e.canSpeak(t, locale: locale)) {
          coversAny = true;
        } else {
          coversAll = false;
        }
      }
      if (coversAll) {
        await e.speakSequence(texts, locale: locale);
        return;
      }
      if (coversAny) break; // preferred-but-partial -> per-token
    }
    // Mixed: route EACH token to its own best engine, so only a clip-less token
    // (a connector with no clip yet) uses system TTS, never the whole sentence.
    for (final t in texts) {
      final engine = await _pickFor(t, locale);
      await engine.speakSequence([t], locale: locale);
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
