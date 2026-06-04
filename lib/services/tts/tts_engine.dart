/// TTS engine interface.
///
/// All Text-to-Speech call sites go through this interface. See
/// docs/adr/0004-tts-strategy.md for the rationale: MVP ships only
/// [SystemTTSEngine], but the interface lets us swap in [PiperTTSEngine] in
/// Phase 2 without touching call sites.
///
/// Voice-output behavior modes (On / On-request / Off / ALS) are a
/// higher-level concern decided in Settings and handled at call-site time,
/// not in the engine itself. The engine just speaks when asked.
library;

import 'dart:ui';

abstract class TTSEngine {
  /// Speaks [text] in the closest available voice for [locale].
  ///
  /// Fire-and-forget. Future completes when the request is dispatched, not
  /// when audio playback ends.
  Future<void> speak(String text, {required Locale locale});

  /// Speaks [texts] in order as a single sentence replay (ADR 0010).
  ///
  /// The bundled-clip engine concatenates the per-word clips it already ships,
  /// so the whole-sentence replay stays on the reliable bundled path rather
  /// than synthesizing fresh audio. This matters most for Arabic, where ADR
  /// 0008 made bundled audio mandatory because system Arabic TTS is unreliable
  /// and a silent replay (the child presenting their whole message) is the
  /// worst possible failure. A text-agnostic engine (system TTS) speaks the
  /// joined string instead. [FallbackTTSEngine] prefers whichever single
  /// engine can speak every token.
  Future<void> speakSequence(List<String> texts, {required Locale locale});

  /// Returns true if this engine can speak THIS [text] in [locale] right now.
  ///
  /// Capability is per-utterance, not just per-locale: a bundled-clip engine
  /// covers only the fixed core vocabulary, so it answers true for a tapped
  /// core word but false for free-typed text in the same locale, letting
  /// [FallbackTTSEngine] fall through to system TTS. A system engine is
  /// text-agnostic and answers purely on locale support.
  Future<bool> canSpeak(String text, {required Locale locale});

  /// Interrupts any in-progress utterance.
  Future<void> stop();

  /// Releases any platform resources held by the engine.
  Future<void> dispose();
}
