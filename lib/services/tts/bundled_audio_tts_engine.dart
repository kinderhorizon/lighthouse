/// Bundled-audio TTS implementation (the primary path).
///
/// Plays build-time pre-rendered clips for the fixed core vocabulary, shipped
/// under assets/audio/ and described by assets/audio/manifest.json. This is the
/// PRIMARY speech path per the docs/adr/0004-tts-strategy.md amendment: the
/// vocabulary is a small finite set, so real-time synthesis is unnecessary and
/// bundling eliminates the silent-tap failure mode (critical for Arabic, where
/// many devices ship no system voice).
///
/// Capability is per-utterance: [canSpeak] is true only when a clip exists for
/// (locale, text). Free-typed text has no clip, so [FallbackTTSEngine] falls
/// through to [SystemTTSEngine] for it. The clip lookup keys on the button's
/// voice_out string exactly as the board model resolves it (`voiceOutFor`).
///
/// The [AudioPlayer] is created lazily on first playback, so constructing this
/// engine (e.g. in the provider, or in a host test with an empty manifest)
/// touches no platform audio resources.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:just_audio/just_audio.dart';

import '../ota/content_overlay_store.dart';
import 'tts_engine.dart';

class BundledAudioTTSEngine implements TTSEngine {
  BundledAudioTTSEngine({
    AssetBundle? bundle,
    this.manifestAsset = 'assets/audio/manifest.json',
    ContentOverlayStore? contentOverlay,
  })  : _bundle = bundle ?? rootBundle,
        _contentOverlay = contentOverlay;

  /// Asset key of the clip manifest.
  final String manifestAsset;

  final AssetBundle _bundle;

  /// OTA overlay (ADR 0017). When a corrected clip has been applied for a
  /// clip's content path, playback uses the overlay FILE instead of the bundled
  /// asset (a "wrong vocal" fix). Null = bundled-only.
  final ContentOverlayStore? _contentOverlay;

  /// (languageCode, voice_out) -> clip asset path. Loaded once, lazily.
  Future<Map<String, String>>? _index;

  /// Lazily created; null until the first clip actually plays.
  AudioPlayer? _player;

  /// Monotonic token guarding the single shared [_player]. Every playback
  /// request (a per-tap [speak], a [speakSequence] replay, or a [stop])
  /// increments it and captures its value; a long-running sequence checks the
  /// token between clips and yields the moment a newer request supersedes it.
  /// This serialises access so a tap landing DURING a replay does not collide
  /// on the shared player and garble or drop words (review NEW-C). Latest
  /// request wins, which for an AAC tap is the right behavior.
  int _generation = 0;

  static String _key(String languageCode, String text) =>
      '$languageCode\u0000$text';

  Future<Map<String, String>> _loadIndex() async {
    try {
      final raw = await _bundle.loadString(manifestAsset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final clips = (json['clips'] as List?) ?? const [];
      final map = <String, String>{};
      for (final entry in clips.cast<Map<String, dynamic>>()) {
        final locale = entry['locale'] as String?;
        final voiceOut = entry['voice_out'] as String?;
        final path = entry['path'] as String?;
        if (locale != null && voiceOut != null && path != null) {
          map[_key(locale, voiceOut)] = path;
        }
      }
      return map;
    } catch (_) {
      // No manifest, malformed manifest, or no clips yet: this engine simply
      // never claims an utterance, and the fallback chain uses system TTS.
      // A corrupt real manifest is caught by tools/verify_assets.dart in CI,
      // not here, because at runtime degrading to system TTS beats crashing.
      return const <String, String>{};
    }
  }

  Future<String?> _clipPathFor(String text, Locale locale) async {
    final index = await (_index ??= _loadIndex());
    return index[_key(locale.languageCode, text)];
  }

  /// If a corrected clip has been OTA-applied for the bundled [assetPath],
  /// returns the overlay file's path to play instead; else null (use the
  /// bundled asset). The content path is the asset key minus the leading
  /// `assets/` (ADR 0017). Overlaying never changes WHETHER a clip exists
  /// (canSpeak is manifest-driven), only which bytes play.
  Future<String?> overlayClipFilePathFor(String assetPath) async {
    final overlay = _contentOverlay;
    if (overlay == null) return null;
    const prefix = 'assets/';
    final contentPath = assetPath.startsWith(prefix)
        ? assetPath.substring(prefix.length)
        : assetPath;
    final file = await overlay.overlayFileFor(contentPath);
    return file?.path;
  }

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async =>
      await _clipPathFor(text, locale) != null;

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    final path = await _clipPathFor(text, locale);
    if (path == null) return; // Not ours; the composite should not route here.

    final player = _player ??= AudioPlayer();
    // Claim the shared player; supersedes any in-flight clip or replay (NEW-C).
    final gen = ++_generation;
    // Prefer an OTA-overlaid clip file over the bundled asset (ADR 0017).
    final overlayPath = await overlayClipFilePathFor(path);
    if (gen != _generation) return; // superseded during overlay lookup
    // setAsset/setFilePath loads + decodes the clip and resets prior playback;
    // play() is intentionally not awaited so the call returns once playback is
    // dispatched, never blocking the tap (see [[persistence-never-blocks-tts]]).
    if (overlayPath != null) {
      await player.setFilePath(overlayPath);
    } else {
      await player.setAsset(path);
    }
    if (gen != _generation) return; // a newer request took over while loading
    // play() is fire-and-forget so the tap never blocks; swallow a late
    // playback error here too. Without the catchError, an async player failure
    // would escape to the zone handler and reach crash capture from a tap,
    // which _speakSafely (it only awaits speak()) cannot catch. Speech must
    // never crash a tap (see [[persistence-never-blocks-tts]]).
    unawaited(player.play().catchError((Object _) {}));
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    // Resolve every token's clip, then play them as ONE gapless playlist
    // (setAudioSources), rather than setAsset-per-word. The per-word reload gap
    // made the sentence replay sound slow and choppy (clinical review); a playlist
    // flows word-to-word naturally and needs a single completion wait. We wait
    // for processingState==completed (NOT play()'s future, which in just_audio
    // completes on pause/stop, not at end-of-track) so the last word is never
    // cut off (clinical review). A token with no clip is dropped; the composite
    // only routes clip-backed tokens here.
    final sources = <AudioSource>[];
    for (final text in texts) {
      final path = await _clipPathFor(text, locale);
      if (path == null) continue;
      // Prefer an OTA-overlaid clip file over the bundled asset (ADR 0017).
      final overlayPath = await overlayClipFilePathFor(path);
      sources.add(overlayPath != null
          ? AudioSource.file(overlayPath)
          : AudioSource.asset(path));
    }
    if (sources.isEmpty) return;

    final player = _player ??= AudioPlayer();
    final gen = ++_generation; // claim the player; supersedes prior playback (NEW-C)
    await player.setAudioSources(sources);
    if (gen != _generation) return; // a newer tap/replay took over while loading
    // Subscribe to the completion BEFORE starting playback. processingStateStream
    // is a broadcast stream that does not replay its current value, and the
    // player is reused across replays (`_player ??=`), so attaching the listener
    // after play() can miss the `completed` transition (or never see a fresh one
    // if the reused player is already at `completed`) and then block until the
    // 10s timeout. Capturing the future first closes that race; the short-circuit
    // handles the already-completed reused-player case. Bounded so a corrupt clip
    // still can't hang.
    final Future<ProcessingState> finished =
        player.processingState == ProcessingState.completed
            ? Future.value(ProcessingState.completed)
            : player.processingStateStream
                .firstWhere((s) => s == ProcessingState.completed)
                .timeout(const Duration(seconds: 10),
                    onTimeout: () => ProcessingState.completed);
    // Swallow a late playback error (see speak()): a bad clip must not crash a tap.
    unawaited(player.play().catchError((Object _) {}));
    await finished;
  }

  @override
  Future<void> stop() async {
    ++_generation; // cancel any in-flight clip / sequence (NEW-C)
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
