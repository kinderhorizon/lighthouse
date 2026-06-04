import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/bandit/beta_sampler.dart';

void main() {
  group('BetaSampler.sample', () {
    test('always returns a value in [0, 1] across shapes', () {
      final sampler = const BetaSampler();
      final rng = math.Random(42);
      // Cover the full cold-start range, baseWeight in [0.05, 0.95].
      // alpha = 2 * baseWeight, beta = 2 * (1 - baseWeight).
      const shapePairs = <(double, double)>[
        (0.1, 1.9), // very weak signal, almost-zero prior on alpha
        (0.5, 1.5),
        (1.0, 1.0),
        (1.5, 0.5),
        (1.9, 0.1),
        (5.0, 5.0),
        (100.0, 100.0), // deep posterior, narrow distribution
      ];
      for (final (a, b) in shapePairs) {
        for (var i = 0; i < 500; i++) {
          final draw = sampler.sample(a, b, rng);
          expect(draw, inInclusiveRange(0.0, 1.0),
              reason: 'alpha=$a beta=$b iter=$i draw=$draw');
          expect(draw.isFinite, isTrue);
        }
      }
    });

    test('sample mean approaches alpha / (alpha + beta) (LLN)', () {
      final sampler = const BetaSampler();
      final rng = math.Random(7);
      // Pick a non-symmetric pair so the test is sensitive to a bug
      // that biases samples toward 0.5.
      const alpha = 8.0;
      const beta = 2.0;
      const trials = 5000;
      var sum = 0.0;
      for (var i = 0; i < trials; i++) {
        sum += sampler.sample(alpha, beta, rng);
      }
      final mean = sum / trials;
      final expected = alpha / (alpha + beta); // 0.8
      // True std-dev of Beta(8,2) is ~0.121; SEM at n=5000 is ~0.0017.
      // 0.02 is a safe tolerance that still catches bugs that bias by
      // more than ~ 1 standard error.
      expect(mean, closeTo(expected, 0.02));
    });

    test('seeded RNG produces deterministic draws', () {
      final sampler = const BetaSampler();
      final rng1 = math.Random(1234);
      final rng2 = math.Random(1234);
      for (var i = 0; i < 50; i++) {
        final a = sampler.sample(1.4, 0.6, rng1);
        final b = sampler.sample(1.4, 0.6, rng2);
        expect(a, b);
      }
    });

    test('asymmetry: higher alpha biases draws upward', () {
      final sampler = const BetaSampler();
      final rng = math.Random(99);
      // Beta(20, 2) sits near 0.91; very few draws should fall below
      // 0.5. Pick a tolerant threshold so we are testing the bias, not
      // memorizing a quantile.
      var below = 0;
      const trials = 1000;
      for (var i = 0; i < trials; i++) {
        if (sampler.sample(20.0, 2.0, rng) < 0.5) below++;
      }
      expect(below, lessThan(trials ~/ 20),
          reason: 'Beta(20, 2) should rarely draw below 0.5');
    });

    test('handles very small shapes without throwing or returning NaN',
        () {
      final sampler = const BetaSampler();
      final rng = math.Random(3);
      // Smallest shapes we ever see in production: baseWeight at the
      // extremes from the schema (~0.05 -> alpha ~ 0.1).
      for (var i = 0; i < 1000; i++) {
        final draw = sampler.sample(0.1, 1.9, rng);
        expect(draw.isFinite, isTrue);
        expect(draw, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
