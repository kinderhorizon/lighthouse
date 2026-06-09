/// Utterance (sentence bar) provider.
///
/// Holds the ordered list of buttons the child has tapped into the current
/// sentence (ADR 0010). Stores [AACButton]s rather than strings so the bar can
/// render each token's pictogram and re-resolve its label/voice-out for the
/// active locale. `keepAlive` so the sentence survives board navigation: the
/// auto-return-home behavior (ADR 0009) rebuilds the widget subtree but must
/// not wipe a half-built sentence.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/models.dart';

part 'utterance_provider.g.dart';

@Riverpod(keepAlive: true)
class Utterance extends _$Utterance {
  @override
  List<AACButton> build() => const [];

  /// Appends a tapped word/phrase button to the sentence. Folder buttons are
  /// navigation, not communication, and are ignored defensively.
  void append(AACButton button) {
    if (button.type == AACButtonType.folder) return;
    state = [...state, button];
  }

  /// Commits a tapped button to the bar with the right semantics for its type:
  /// a WORD accumulates (it composes a longer sentence). A PHRASE button is a
  /// complete utterance ("I need to go to the bathroom"), spoken immediately on
  /// tap, so it does NOT enter the composition bar at all: appending it would
  /// run on into the following words (clinical review: "...bathroom water"), and
  /// clearing would silently discard a half-built sentence (review NEW-D). It
  /// therefore leaves whatever the parent is composing untouched. Folders are
  /// navigation and never commit.
  void commit(AACButton button) {
    if (button.type == AACButtonType.word) {
      append(button);
    }
  }

  /// Removes the last token (backspace). No-op when empty.
  void backspace() {
    if (state.isEmpty) return;
    state = state.sublist(0, state.length - 1);
  }

  /// Clears the whole sentence.
  void clear() {
    if (state.isEmpty) return;
    state = const [];
  }

  /// Removes the first [count] tokens, leaving the rest. Used by the replay
  /// auto-clear to drop only the tokens it actually spoke (the prefix captured
  /// when Speak was pressed), so words the child taps DURING playback (appended
  /// at the end) survive instead of being wiped with the whole bar. Clamps to
  /// the current length and is a no-op for a non-positive count.
  void removeLeading(int count) {
    if (count <= 0 || state.isEmpty) return;
    if (count >= state.length) {
      state = const [];
      return;
    }
    state = state.sublist(count);
  }
}
