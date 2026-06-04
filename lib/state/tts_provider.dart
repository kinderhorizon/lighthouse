/// TTS provider.
///
/// Composes the priority chain: bundled pre-rendered clips first (the primary
/// path for the fixed core vocabulary), then system TTS as the fallback for
/// free-typed text and any locale/word with no clip yet. See
/// docs/adr/0004-tts-strategy.md (and its amendment). Which locales get bundled
/// clips is governed by the locale registry's `ttsStrategy`; the bundled engine
/// itself is purely manifest-driven, so an empty manifest (no clips generated
/// yet) cleanly degrades the whole app to system TTS.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/services.dart';
import 'content_overlay_provider.dart';

part 'tts_provider.g.dart';

@Riverpod(keepAlive: true)
TTSEngine ttsEngine(TtsEngineRef ref) {
  final engine = FallbackTTSEngine([
    // Shares the one overlay store so a corrected clip (OTA, ADR 0017) plays
    // instead of the bundled asset.
    BundledAudioTTSEngine(
      contentOverlay: ref.watch(contentOverlayStoreProvider),
    ),
    SystemTTSEngine(),
  ]);
  ref.onDispose(engine.dispose);
  return engine;
}
