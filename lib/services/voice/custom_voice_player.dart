/// Plays parent-recorded custom voice clips (ADR 0019).
///
/// A thin wrapper over a single lazily-created just_audio [AudioPlayer], kept
/// separate from the TTS engine's player so a custom-voice tap and a TTS clip
/// never collide on one player. Like the TTS engine, a monotonic generation
/// guards the shared player so the latest request wins (right for an AAC tap),
/// and playback is fire-and-forget: hearing the word must never block on, or be
/// crashed by, the audio layer (see [[persistence-never-blocks-tts]]).
library;

import 'dart:async';

import 'package:just_audio/just_audio.dart';

class CustomVoicePlayer {
  AudioPlayer? _player;
  int _generation = 0;

  /// Loads and plays the clip at [filePath]. Supersedes any in-flight playback.
  /// Fire-and-forget: returns once playback is dispatched, not at end-of-clip.
  ///
  /// Returns true when the clip loaded and playback was dispatched (or a newer
  /// request superseded this one mid-load, which is a success for THIS call: the
  /// child is hearing the newer tap). Returns false ONLY when [setFilePath]
  /// threw, i.e. the mapped clip is missing/corrupt; the caller MUST then fall
  /// back to TTS so the tile is never silent (ADR 0004 / ADR 0019).
  Future<bool> play(String filePath) async {
    final player = _player ??= AudioPlayer();
    final gen = ++_generation;
    try {
      await player.setFilePath(filePath);
    } catch (_) {
      // Distinguish supersession from a genuinely bad clip (item 2). just_audio
      // throws PlayerInterruptedException out of setFilePath when a NEWER request
      // interrupts this load; that is not a corrupt clip, it is latest-wins
      // working as intended, so report success. Returning false here would make
      // the caller "fall back to TTS", which stops the newer tap's playback and
      // speaks the OLD word: latest-wins inverted, the parent recording dropped.
      // Only a failure with the generation UNCHANGED is a real missing/corrupt
      // clip the caller must fall back on.
      if (gen != _generation) return true;
      return false;
    }
    if (gen != _generation) return true; // a newer request took over: not a fail
    unawaited(player.play().catchError((Object _) {}));
    return true;
  }

  /// Plays [filePath] and AWAITS end-of-clip, so the sentence replay can play a
  /// recorded clip in order with the spoken words around it (clinical review: replay
  /// must use the recording, not fall back to TTS). Unlike [play] (fire-and-
  /// forget for a single tap), this resolves only when the clip finishes, a
  /// newer request supersedes it, or a 10s safety timeout fires. We wait on
  /// processingState==completed (NOT play()'s future, which in just_audio
  /// completes on pause/stop, not at end-of-track) so the clip is never cut off,
  /// mirroring the bundled TTS engine's sequence wait.
  /// Returns true when the clip loaded and played to completion (or a newer
  /// request superseded it). Returns false ONLY when [setFilePath] threw
  /// (missing/corrupt clip), so the replay loop can speak that token via TTS
  /// in order instead of dropping it (ADR 0019).
  Future<bool> playToCompletion(String filePath) async {
    final player = _player ??= AudioPlayer();
    final gen = ++_generation;
    try {
      await player.setFilePath(filePath);
    } catch (_) {
      // Supersession (PlayerInterruptedException) is not a corrupt clip; only a
      // failure with the generation unchanged is. See [play] (item 2).
      if (gen != _generation) return true;
      return false; // missing/corrupt clip: signal failure for TTS fallback
    }
    if (gen != _generation) return true; // a newer request took over: not a fail
    // Resolve on completed OR idle: a newer request's [stop] drives the shared
    // player to idle (not completed), so accepting idle lets a superseding tap
    // end this wait crisply instead of parking on it until the 10s timeout.
    final Future<ProcessingState> finished =
        player.processingState == ProcessingState.completed
            ? Future.value(ProcessingState.completed)
            : player.processingStateStream
                .firstWhere((s) =>
                    s == ProcessingState.completed || s == ProcessingState.idle)
                .timeout(const Duration(seconds: 10),
                    onTimeout: () => ProcessingState.completed);
    unawaited(player.play().catchError((Object _) {}));
    await finished;
    return true;
  }

  Future<void> stop() async {
    ++_generation;
    await _player?.stop();
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
