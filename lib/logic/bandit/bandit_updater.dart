/// Bandit update logic.
///
/// PRD section 3.2 ON_TAP rule:
///   bandit[state_key][button_id].alpha += 1.0
///   FOR each btn IN top_3_predictions:
///     IF btn != button_id:
///       bandit[state_key][btn].beta += 0.5
///
/// First-time observation of a (stateKey, buttonId) pair seeds the
/// row with the weak cold-start prior from ADR 0003:
///   alpha = 2 * base_weight
///   beta  = 2 * (1 - base_weight)
/// Real observations then accumulate on top.
///
/// `observationCount` tracks REAL observations only (the cold-start
/// prior is NOT counted). ADR 0003's visual-threshold table indexes
/// against this number, and the table only makes sense if "first real
/// observation" reads as 1 rather than the prior's pseudo-2.
///
/// Pure-Dart and side-effect-free outside of the [BanditStore] it is
/// handed. No platform calls, no Isar dependency directly; tests
/// inject an in-memory store.
library;

import '../../models/models.dart';
import '../../persistence/persistence.dart';
import 'bandit_store.dart';
import 'contextual_cold_start.dart';

class BanditUpdater {
  BanditUpdater({
    required BanditStore store,
    ContextualColdStart coldStart = const ContextualColdStart.empty(),
    DateTime Function()? clock,
  })  : _store = store,
        _coldStart = coldStart,
        _clock = clock ?? DateTime.now;

  final BanditStore _store;
  // Context-aware cold-start prior. Defaults to the empty (no-data) resolver so
  // existing callers/tests keep today's base_weight behaviour unchanged. MUST
  // be the same artifact the ranker uses (both come from one provider) so a
  // row is never seeded under a different prior than it was ranked under.
  final ContextualColdStart _coldStart;
  final DateTime Function() _clock;

  /// Applies the gentle-penalty rule for a single tap.
  ///
  /// CONCURRENCY: this is a read-modify-write (load rows, mutate, [putStateAll])
  /// that is NOT atomic on its own. It is correct only because its sole runtime
  /// caller serializes invocations through the process-global tap queue (see
  /// `_tapQueue` / `_recordTap` in main.dart, review NEW-A). Any new caller MUST
  /// run on that serialized path, or overlapping calls will lose updates again.
  /// Unit tests may call it directly because they never overlap.
  ///
  /// [stateKey] is the context-key at the moment of tap (the caller
  /// composes it via [ContextManager.currentStateKey] BEFORE updating
  /// any in-memory context state).
  ///
  /// [tappedButton] is the button the child selected.
  ///
  /// [top3Predictions] is the list of buttons the bandit had just
  /// suggested (top 3 by Thompson Sample). In Phase 2 this is always
  /// empty because the glow renderer (Phase 3) is the only consumer
  /// of predictions; the penalty branch is a no-op until Phase 3
  /// wires the prediction loop.
  Future<void> applyTap({
    required String stateKey,
    required AACButton tappedButton,
    List<AACButton> top3Predictions = const [],
  }) async {
    // Reward the winner.
    final winner = await _loadOrPrior(stateKey, tappedButton);
    winner.alpha += 1.0;
    winner.observationCount += 1;
    winner.updatedAt = _clock().toUtc();

    // Gentle penalty for every prediction the child IGNORED (i.e.,
    // glowing buttons they did not tap). Predictions identical to
    // the tap are skipped; a button that glowed AND got tapped is
    // a pure reward.
    final rows = <BanditStateV1>[winner];
    for (final predicted in top3Predictions) {
      if (predicted.id == tappedButton.id) continue;
      final row = await _loadOrPrior(stateKey, predicted);
      row.beta += 0.5;
      row.observationCount += 1;
      row.updatedAt = _clock().toUtc();
      rows.add(row);
    }

    // One transaction for the winner + penalties (was one per row).
    await _store.putStateAll(rows);
  }

  Future<BanditStateV1> _loadOrPrior(
    String stateKey,
    AACButton button,
  ) async {
    final existing = await _store.getState(
      stateKey: stateKey,
      buttonId: button.id,
    );
    if (existing != null) return existing;
    // Cold-start row, seeded from the SAME shared context-aware prior the ranker
    // scores a no-row button under (so learning and ranking can never diverge;
    // the clamp also keeps a crafted base_weight from persisting a degenerate
    // row). priorFor() applies the (prev, candidate) mean from stateKey when the
    // artifact has one, else base_weight. observationCount=0 here; the caller
    // increments it after the real observation it represents is applied.
    // updatedAt is a placeholder that will also be refreshed.
    final prior = _coldStart.priorFor(stateKey, button);
    return BanditStateV1()
      ..stateKey = stateKey
      ..buttonId = button.id
      ..alpha = prior.alpha
      ..beta = prior.beta
      ..observationCount = 0
      ..updatedAt = _clock().toUtc();
  }
}
