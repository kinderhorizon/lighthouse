/// Top-K predictor for the contextual bandit.
///
/// Given the current `stateKey` and the buttons visible on the active
/// board, draws a Beta sample for every candidate (existing rows + a
/// synthetic cold-start row for any button without a row yet) and
/// returns the top K by sampled draw.
///
/// Folders are excluded from ranking: navigating a folder is not a
/// communication act per ADR 0003, so folders never glow.
///
/// Pure Dart, no Isar / Flutter dependency. Takes a [BanditStore] so
/// tests can swap in a fake.
library;

import 'dart:math' as math;

import '../../models/models.dart';
import 'bandit_store.dart';
import 'beta_sampler.dart';
import 'contextual_cold_start.dart';

class RankedPrediction {
  const RankedPrediction({
    required this.button,
    required this.draw,
    required this.posteriorMean,
    required this.observationCount,
  });

  final AACButton button;
  final double draw;
  final double posteriorMean;
  final int observationCount;
}

class BanditRanker {
  BanditRanker({
    required BanditStore store,
    ContextualColdStart coldStart = const ContextualColdStart.empty(),
    BetaSampler sampler = const BetaSampler(),
  })  : _store = store,
        _coldStart = coldStart,
        _sampler = sampler;

  final BanditStore _store;
  // Context-aware cold-start prior. Defaults to the empty (no-data) resolver so
  // existing callers/tests keep today's base_weight behaviour unchanged.
  final ContextualColdStart _coldStart;
  final BetaSampler _sampler;

  /// Returns the top [k] predictions for [stateKey] over the candidate
  /// [buttons], ranked by Thompson-sampled draw descending. Folders are
  /// dropped before ranking.
  ///
  /// [rng] is passed in so tests can seed for deterministic ranking and
  /// production can pass a fresh non-seeded RNG. The bandit ranks once
  /// per stateKey change, not per tap, so RNG cost is negligible.
  Future<List<RankedPrediction>> topK({
    required String stateKey,
    required List<AACButton> buttons,
    required int k,
    required math.Random rng,
  }) async {
    final candidates = buttons
        .where((b) => b.type != AACButtonType.folder)
        .toList(growable: false);
    if (candidates.isEmpty || k <= 0) return const [];

    // One read for the whole context, then in-memory lookups. Avoids an
    // N+1 query (one getState per button) on low-end tablets. Behavior
    // is identical: a button with no row still falls back to the
    // cold-start prior below.
    final rows = await _store.getAllForState(stateKey);
    final rowByButtonId = {for (final r in rows) r.buttonId: r};

    final draws = <RankedPrediction>[];
    for (final button in candidates) {
      final row = rowByButtonId[button.id];
      // A learned row is used only if its Beta params honor the sampler's
      // strictly-positive/finite precondition. A no-row button OR a corrupt/
      // legacy row (one persisted under the pre-clamp formula, or Isar
      // corruption) falls back to the clamped cold-start prior, so a
      // degenerate/NaN draw can never reach the sampler or pin the sort. Both
      // writers now clamp, so a bad row is not producible going forward; this
      // is the fail-safe for pre-fix or corrupted state.
      final double alpha;
      final double beta;
      final int obs;
      if (row != null &&
          row.alpha.isFinite &&
          row.alpha > 0 &&
          row.beta.isFinite &&
          row.beta > 0) {
        alpha = row.alpha;
        beta = row.beta;
        obs = row.observationCount;
      } else {
        // No-row button: score it under the context-aware cold-start prior.
        // priorFor() derives the previous button from stateKey and applies the
        // (prev, candidate) mean when the artifact has one, else base_weight;
        // it routes through the SAME coldStartPrior the updater seeds with.
        final prior = _coldStart.priorFor(stateKey, button);
        alpha = prior.alpha;
        beta = prior.beta;
        obs = 0;
      }
      final draw = _sampler.sample(alpha, beta, rng);
      draws.add(
        RankedPrediction(
          button: button,
          draw: draw,
          posteriorMean: alpha / (alpha + beta),
          observationCount: obs,
        ),
      );
    }

    draws.sort((a, b) => b.draw.compareTo(a.draw));
    return draws.take(k).toList(growable: false);
  }
}
