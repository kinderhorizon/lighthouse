/// Beta(alpha, beta) sampler for the contextual bandit.
///
/// Strategy: sample X ~ Gamma(alpha, 1) and Y ~ Gamma(beta, 1); return
/// X / (X + Y). Gamma sampling uses Marsaglia and Tsang's method for
/// shape >= 1, with the standard shape-boosting trick
/// (X * U^(1/k) ~ Gamma(k, 1) when X ~ Gamma(k+1, 1), U ~ Uniform[0,1))
/// for shape < 1. The cold-start prior in ADR 0003 produces alpha and
/// beta as low as 2 * 0.05 = 0.1, so a shape-< 1 path is mandatory.
///
/// Pure Dart. Takes a [Random] so tests can seed for determinism and
/// production can pass a fresh non-seeded RNG.
library;

import 'dart:math' as math;

class BetaSampler {
  const BetaSampler();

  /// Returns a single draw from Beta(alpha, beta), with both parameters
  /// strictly positive. Caller should pre-clamp to a small epsilon if
  /// alpha or beta could be zero by construction.
  double sample(double alpha, double beta, math.Random rng) {
    assert(alpha > 0, 'alpha must be > 0, got $alpha');
    assert(beta > 0, 'beta must be > 0, got $beta');
    final x = _sampleGamma(alpha, rng);
    final y = _sampleGamma(beta, rng);
    final sum = x + y;
    if (sum == 0) {
      // Degenerate (both gammas drew exactly zero). Fall back to the
      // expected value so we still return a valid number in [0, 1].
      return alpha / (alpha + beta);
    }
    return x / sum;
  }

  /// Marsaglia and Tsang's method for shape >= 1, plus the
  /// Stuart and Marsaglia shape-boosting trick for shape < 1.
  double _sampleGamma(double shape, math.Random rng) {
    if (shape < 1.0) {
      final g = _sampleGammaAtLeastOne(shape + 1.0, rng);
      // u in (0, 1] to avoid log(0). dart:math nextDouble is [0, 1).
      final u = 1.0 - rng.nextDouble();
      return g * math.pow(u, 1.0 / shape).toDouble();
    }
    return _sampleGammaAtLeastOne(shape, rng);
  }

  double _sampleGammaAtLeastOne(double shape, math.Random rng) {
    final d = shape - 1.0 / 3.0;
    final c = 1.0 / math.sqrt(9.0 * d);
    while (true) {
      double x;
      double v;
      do {
        x = _nextGaussian(rng);
        v = 1.0 + c * x;
      } while (v <= 0);
      v = v * v * v;
      // u in (0, 1] (1 - nextDouble flips the half-open interval).
      final u = 1.0 - rng.nextDouble();
      final xSquared = x * x;
      if (u < 1.0 - 0.0331 * xSquared * xSquared) {
        return d * v;
      }
      if (math.log(u) <
          0.5 * xSquared + d * (1.0 - v + math.log(v))) {
        return d * v;
      }
    }
  }

  /// Box and Muller transform for a single standard-normal draw.
  /// We discard the second draw rather than caching it; the bandit
  /// samples Beta a few dozen times per frame at most.
  double _nextGaussian(math.Random rng) {
    final u1 = 1.0 - rng.nextDouble();
    final u2 = rng.nextDouble();
    return math.sqrt(-2.0 * math.log(u1)) *
        math.cos(2.0 * math.pi * u2);
  }
}
