/// Process-wide serialization queue for context mutations (review NEW-A).
///
/// BOTH tap persistence (`_recordTap` in main.dart) and sentence-bar edits
/// (backspace / clear, which rewind the prediction context) enqueue here, so a
/// context change can never land out of order. A tap is fire-and-forget and its
/// `ContextManager.recordTap` runs only after its bandit write settles; without
/// a shared queue, a still-draining tap record would overwrite a later delete's
/// context revert and leave the glow predicting from the JUST-DELETED word.
/// Funnelling both through one FIFO makes the last user action win.
///
/// Manual Riverpod (no build_runner), like [contentOverlayStoreProvider]. A
/// plain `Provider` is not auto-disposed, so the single queue lives for the app.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A FIFO chain: each task runs after the previous one settles. A task failure
/// is isolated (caught) so it cannot poison the tasks queued behind it.
class SerialQueue {
  Future<void> _tail = Future<void>.value();

  /// Appends [task] to the chain and returns a future for THIS task.
  Future<void> add(Future<void> Function() task) {
    final scheduled = _tail.then((_) => task());
    _tail = scheduled.catchError((Object _) {});
    return scheduled;
  }
}

/// The single app-wide context-mutation queue.
final tapQueueProvider = Provider<SerialQueue>((ref) => SerialQueue());
