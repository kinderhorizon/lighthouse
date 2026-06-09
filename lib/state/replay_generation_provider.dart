/// Replay generation token (sentence-bar Speak).
///
/// A single monotonic counter shared by the sentence replay and the per-tap
/// speak path, modelled on the per-player `_generation` guard the audio engines
/// already use (latest-wins is the right behavior for an AAC tap).
///
/// A replay claims the next value via [ReplayGeneration.begin]; any per-tap
/// communication act also calls [begin] (from `main._speakSafely`). The
/// mixed-voice replay loop captures its value and re-reads [current] after every
/// awaited segment: the moment it changes (an interrupting tap, or a new
/// replay), the loop aborts instead of resuming the old, now-stale sentence
/// once the child has moved on. Kept out of the audio services because the
/// signal crosses two of them (the TTS engine and the custom-voice player) plus
/// the tap handler.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReplayGeneration {
  int _value = 0;

  /// The current generation. A replay compares this against the value it
  /// captured from [begin]; a mismatch means it has been superseded.
  int get current => _value;

  /// Claims and returns the next generation. Called when a replay starts and
  /// whenever a new communication tap should supersede an in-flight replay.
  int begin() => ++_value;
}

/// keepAlive (a plain, non-autoDispose Provider) so the counter survives the
/// frequent board/widget rebuilds that auto-return-home triggers.
final replayGenerationProvider =
    Provider<ReplayGeneration>((ref) => ReplayGeneration());
