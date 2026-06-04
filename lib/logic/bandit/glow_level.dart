/// Visual confidence level for a single ranked prediction.
///
/// Maps a (posteriorMean, observationCount) pair to one of three levels
/// per ADR 0003 section 2. Observation-count-aware thresholds:
///
/// | Observations | Gold threshold | Shimmer threshold |
/// | 0            | >= 0.75        | >= 0.50           |
/// | 1 to 3       | >= 0.70        | >= 0.40           |
/// | 4 to 10      | >= 0.65        | >= 0.35           |
/// | 11+          | >= 0.60        | >= 0.30           |
///
/// The 11+ band is the PRD's default. Lower bands raise the bar to
/// reduce false-positive cost during the prior-dominated window. The
/// shimmer state remains active early so the app feels alive on day 1;
/// gold is earned over time.
library;

enum GlowLevel {
  none,
  shimmer,
  gold;

  bool get isGlowing => this != GlowLevel.none;
}

class _Thresholds {
  const _Thresholds({required this.gold, required this.shimmer});
  final double gold;
  final double shimmer;
}

const _band0 = _Thresholds(gold: 0.75, shimmer: 0.50);
const _band1to3 = _Thresholds(gold: 0.70, shimmer: 0.40);
const _band4to10 = _Thresholds(gold: 0.65, shimmer: 0.35);
const _band11plus = _Thresholds(gold: 0.60, shimmer: 0.30);

_Thresholds _thresholdsFor(int observationCount) {
  assert(observationCount >= 0,
      'observationCount cannot be negative, got $observationCount');
  if (observationCount == 0) return _band0;
  if (observationCount <= 3) return _band1to3;
  if (observationCount <= 10) return _band4to10;
  return _band11plus;
}

/// Computes the glow level for a single prediction.
///
/// [posteriorMean] is `alpha / (alpha + beta)` for the underlying Beta
/// distribution. [observationCount] is the number of REAL observations
/// for the (stateKey, buttonId) pair (the cold-start prior is NOT
/// counted, per ADR 0003).
GlowLevel computeGlowLevel({
  required double posteriorMean,
  required int observationCount,
}) {
  final t = _thresholdsFor(observationCount);
  if (posteriorMean >= t.gold) return GlowLevel.gold;
  if (posteriorMean >= t.shimmer) return GlowLevel.shimmer;
  return GlowLevel.none;
}
