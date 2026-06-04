/// ContextManager.
///
/// Composes the four context dimensions defined by PRD section 3.1
/// (TimeBlock, DayType, WifiHash, PrevButtonID, SemanticContext)
/// into a single state-key string the bandit indexes on.
///
/// State key format (verbatim from PRD):
///   "TimeBlock_DayType|WifiHash|Prev:btn_id|Context:Category"
///
/// Each segment is always present so the key shape is stable; empty
/// segments are explicit (e.g., "Prev:" when no previous button is
/// in memory). The bandit treats different shapes as different
/// contexts, so empty-vs-missing matters.
///
/// Lives in `lib/logic/` because it's pure-Dart with no platform
/// dependencies. WifiHash is supplied by the caller (Session 11 will
/// wire a real source); recording a tap is side-effecting on the
/// in-memory state only.
library;

import 'dart:ui';

import '../../models/models.dart';
import 'semantic_context.dart';
import 'time_context.dart';

class ContextManager {
  ContextManager({
    SemanticContext? semantic,
    this.unknownWifiFallback = 'wifi_UNKNOWN',
  }) : semantic = semantic ?? SemanticContext();

  final SemanticContext semantic;

  /// Used when the caller has no WiFi hash (location permission
  /// denied, no SSID available, etc.). The bandit treats this as a
  /// distinct context, so the child learns a separate Beta posterior
  /// for "wifi unknown" use which is correct (e.g., car / park use).
  final String unknownWifiFallback;

  String? _previousButtonId;

  /// Read-only previous-button accessor. Tests + crash diagnostics
  /// can inspect without reaching through into private state.
  String? get previousButtonId => _previousButtonId;

  /// Builds the state key for [now] under [locale] and with the
  /// (optional) [wifiHash]. Pure: this method does not mutate any
  /// internal state.
  String currentStateKey({
    required DateTime now,
    required Locale locale,
    String? wifiHash,
  }) {
    final tb = timeBlockFor(now).key;
    final dt = dayTypeFor(now, locale).key;
    final wifi = wifiHash == null || wifiHash.isEmpty
        ? unknownWifiFallback
        : wifiHash;
    final prev = _previousButtonId ?? '';
    final ctx = semantic.dominant() ?? '';
    return '${tb}_$dt|$wifi|Prev:$prev|Context:$ctx';
  }

  /// Update the in-memory context after a tap. Updates the
  /// "previous button" pointer and decays + bumps the semantic
  /// tracker. Called from the board's tap handler AFTER the bandit
  /// update so the bandit sees the state-key the tap was made
  /// against, not the post-tap state.
  void recordTap(AACButton button) {
    _previousButtonId = button.id;
    semantic.recordTap(button.category);
  }

  /// Re-derives the context from the CURRENT sentence after the parent edits
  /// the bar (backspace / clear). Sets the previous-button pointer to the last
  /// remaining token (null when the bar is empty, i.e. sentence start) and
  /// rebuilds the semantic tracker by replaying the remaining tokens in order.
  ///
  /// A normal tap advances the context forward via [recordTap]; deleting a word
  /// must move it BACK so predictions re-evaluate against what is actually left
  /// on the bar (otherwise the glow keeps suggesting "what comes after" the
  /// already-deleted word). Replay is an order-faithful reconstruction: the
  /// exact decay timing of the original taps is not recoverable, but the most
  /// recent remaining token still dominates, which is what drives the glow.
  void syncToSentence(List<AACButton> sentence) {
    _previousButtonId = sentence.isEmpty ? null : sentence.last.id;
    semantic.clear();
    for (final button in sentence) {
      semantic.recordTap(button.category);
    }
  }

  /// Test seam + "Reset learned state" path. Clears the in-memory
  /// context but does NOT touch persisted bandit state. The
  /// repository's clearAll wipes Isar; this wipes the volatile half.
  void reset() {
    _previousButtonId = null;
    semantic.clear();
  }
}
