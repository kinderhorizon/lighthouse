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
  Future<void> speak(String text, {required Locale locale}) async {
    final engine = await _pickFor(text, locale);
    await engine.speak(text, locale: locale);
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    if (texts.isEmpty) return;
    final gen = ++_generation; // claim; supersedes any in-flight sequence
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
      if (gen != _generation) return; // superseded while probing engines
      if (coversAll) {
        // One engine covers all: it plays the whole list and self-supersedes on
        // [stop] (bundled via its own token, system because flutter_tts.stop
        // completes the awaited utterance), so no per-token check is needed here.
        await e.speakSequence(texts, locale: locale);
        return;
      }
      if (coversAny) break; // preferred-but-partial -> per-token
    }
    // Mixed: route EACH token to its own best engine, so only a clip-less token
    // (a connector with no clip yet) uses system TTS, never the whole sentence.
    // Re-check the token between (and right before) each dispatch so a tap that
    // calls stop() mid-sequence aborts here instead of speaking stale tokens
    // over the child's tap (P0-2 interleaving B).
    for (final t in texts) {
      if (gen != _generation) return;
      final engine = await _pickFor(t, locale);
      if (gen != _generation) return; // superseded during the async pick
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
