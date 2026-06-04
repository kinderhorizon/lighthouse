import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/bandit/glow_level.dart';

void main() {
  group('computeGlowLevel (ADR 0003 observation-count-aware thresholds)', () {
    group('band 0 (no observations): gold>=0.75, shimmer>=0.50', () {
      test('gold exact', () {
        expect(
            computeGlowLevel(posteriorMean: 0.75, observationCount: 0),
            GlowLevel.gold);
      });
      test('gold just below is shimmer', () {
        expect(
            computeGlowLevel(posteriorMean: 0.749, observationCount: 0),
            GlowLevel.shimmer);
      });
      test('shimmer exact', () {
        expect(
            computeGlowLevel(posteriorMean: 0.50, observationCount: 0),
            GlowLevel.shimmer);
      });
      test('below shimmer is none', () {
        expect(
            computeGlowLevel(posteriorMean: 0.499, observationCount: 0),
            GlowLevel.none);
      });
    });

    group('band 1 to 3 observations: gold>=0.70, shimmer>=0.40', () {
      test('gold exact at lower edge (obs=1)', () {
        expect(
            computeGlowLevel(posteriorMean: 0.70, observationCount: 1),
            GlowLevel.gold);
      });
      test('gold exact at upper edge (obs=3)', () {
        expect(
            computeGlowLevel(posteriorMean: 0.70, observationCount: 3),
            GlowLevel.gold);
      });
      test('shimmer at obs=2', () {
        expect(
            computeGlowLevel(posteriorMean: 0.40, observationCount: 2),
            GlowLevel.shimmer);
      });
    });

    group('band 4 to 10 observations: gold>=0.65, shimmer>=0.35', () {
      test('gold exact at lower edge (obs=4)', () {
        expect(
            computeGlowLevel(posteriorMean: 0.65, observationCount: 4),
            GlowLevel.gold);
      });
      test('gold exact at upper edge (obs=10)', () {
        expect(
            computeGlowLevel(posteriorMean: 0.65, observationCount: 10),
            GlowLevel.gold);
      });
      test('below gold is shimmer at obs=10', () {
        expect(
            computeGlowLevel(posteriorMean: 0.649, observationCount: 10),
            GlowLevel.shimmer);
      });
      test('shimmer exact at obs=10', () {
        expect(
            computeGlowLevel(posteriorMean: 0.35, observationCount: 10),
            GlowLevel.shimmer);
      });
    });

    group('band 11+ (PRD defaults): gold>=0.60, shimmer>=0.30', () {
      test('gold exact at obs=11 (first observation in deep band)', () {
        expect(
            computeGlowLevel(posteriorMean: 0.60, observationCount: 11),
            GlowLevel.gold);
      });
      test('shimmer exact at obs=11', () {
        expect(
            computeGlowLevel(posteriorMean: 0.30, observationCount: 11),
            GlowLevel.shimmer);
      });
      test('below shimmer is none', () {
        expect(
            computeGlowLevel(posteriorMean: 0.299, observationCount: 11),
            GlowLevel.none);
      });
      test('deep posterior (obs=10000) still uses 11+ thresholds', () {
        expect(
            computeGlowLevel(posteriorMean: 0.60, observationCount: 10000),
            GlowLevel.gold);
      });
    });

    test('band boundaries are non-decreasing as observations grow', () {
      // The threshold table is monotone: more observations means an
      // equal-or-lower bar to reach gold (and shimmer). This guarantees
      // a (mean, obs) pair that glows at one band cannot un-glow when
      // observations cross to the next band. The threshold table needs
      // edits if this ever fails.
      const meanGoldAtObs0 = 0.75;
      for (final obs in [1, 3, 4, 10, 11, 100]) {
        expect(
            computeGlowLevel(
                posteriorMean: meanGoldAtObs0, observationCount: obs),
            GlowLevel.gold,
            reason: 'obs=$obs');
      }
      const meanShimmerAtObs0 = 0.50;
      for (final obs in [1, 3, 4, 10, 11, 100]) {
        final level = computeGlowLevel(
            posteriorMean: meanShimmerAtObs0, observationCount: obs);
        expect(level.isGlowing, isTrue, reason: 'obs=$obs');
      }
    });

    test('GlowLevel.isGlowing matches the enum cases', () {
      expect(GlowLevel.none.isGlowing, isFalse);
      expect(GlowLevel.shimmer.isGlowing, isTrue);
      expect(GlowLevel.gold.isGlowing, isTrue);
    });
  });
}
