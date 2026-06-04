/// Unit coverage for [ContextualColdStart] and [prevButtonIdFromStateKey]:
/// the resolver that makes the cold-start prior context-aware (ADR 0003).
///
/// The load-bearing property is FALLBACK PARITY: a missing artifact, a missing
/// `(prev, cand)` entry, or sentence-start all reduce to `coldStartPrior(
/// button.baseWeight)`, i.e. exactly today's context-blind behaviour. Plus the
/// parser must be tolerant (never throw on a malformed artifact) and the
/// stateKey helper must extract the previous button identically for both call
/// sites.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';

AACButton _btn(String id, {double baseWeight = 0.5}) => AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: 'needs',
      baseWeight: baseWeight,
      iconUri: '',
      voiceOut: id,
    );

// A real-shaped stateKey for [prev] (null -> sentence start, bare "Prev:").
String _stateKey(String? prev) =>
    'Morning_Weekday|wifi_UNKNOWN|Prev:${prev ?? ''}|Context:food';

void main() {
  group('prevButtonIdFromStateKey', () {
    test('extracts the Prev: segment', () {
      expect(prevButtonIdFromStateKey(_stateKey('btn_eat')), 'btn_eat');
    });

    test('sentence start (bare "Prev:") -> null', () {
      expect(prevButtonIdFromStateKey(_stateKey(null)), isNull);
    });

    test('a stateKey with no Prev: segment -> null (no throw)', () {
      expect(prevButtonIdFromStateKey('s'), isNull);
      expect(prevButtonIdFromStateKey(''), isNull);
    });

    test('matches by prefix, not position (order-robust)', () {
      expect(
        prevButtonIdFromStateKey('Prev:btn_go|Morning_Weekday|Context:'),
        'btn_go',
      );
    });
  });

  group('ContextualColdStart.meanFor', () {
    final ccs = ContextualColdStart(const {
      'btn_eat': {'btn_more': 0.85, 'btn_happy': 0.15},
    });

    test('returns w\' for a known (prev, cand)', () {
      expect(ccs.meanFor(prevKey: 'btn_eat', candidateId: 'btn_more'), 0.85);
    });

    test('returns null for an unknown prev or candidate', () {
      expect(ccs.meanFor(prevKey: 'btn_eat', candidateId: 'btn_zzz'), isNull);
      expect(ccs.meanFor(prevKey: 'btn_zzz', candidateId: 'btn_more'), isNull);
    });
  });

  group('ContextualColdStart.fromArtifactJson (tolerant parse)', () {
    test('parses a well-formed artifact', () {
      final ccs = ContextualColdStart.fromArtifactJson(const {
        'schema_version': 1,
        'transitions': {
          'btn_eat': {'btn_more': 0.9},
        },
      });
      expect(ccs.meanFor(prevKey: 'btn_eat', candidateId: 'btn_more'), 0.9);
    });

    test('missing/!Map transitions -> empty resolver (never throws)', () {
      expect(
        ContextualColdStart.fromArtifactJson(const {})
            .meanFor(prevKey: 'btn_eat', candidateId: 'btn_more'),
        isNull,
      );
      expect(
        ContextualColdStart.fromArtifactJson(const {'transitions': 'oops'})
            .meanFor(prevKey: 'btn_eat', candidateId: 'btn_more'),
        isNull,
      );
    });

    test('skips non-string keys and non-finite weights', () {
      final ccs = ContextualColdStart.fromArtifactJson(const {
        'transitions': {
          'btn_eat': {
            'btn_more': 0.8,
            'btn_bad': double.nan,
          },
        },
      });
      expect(ccs.meanFor(prevKey: 'btn_eat', candidateId: 'btn_more'), 0.8);
      expect(ccs.meanFor(prevKey: 'btn_eat', candidateId: 'btn_bad'), isNull);
    });
  });

  group('priorFor: known-context suppression vs unknown-context fallback', () {
    // btn_eat is a KNOWN context (row present). btn_more is listed; btn_i and
    // btn_unseen are absent from it (the model did not endorse them after eat).
    final ccs = ContextualColdStart(const {
      'btn_eat': {'btn_more': 0.9},
    });

    void expectMean(({double alpha, double beta}) p, double mean) {
      final expected = coldStartPrior(mean);
      expect(p.alpha, closeTo(expected.alpha, 1e-9));
      expect(p.beta, closeTo(expected.beta, 1e-9));
    }

    test('uses w\' when the artifact lists the (prev, cand)', () {
      expectMean(ccs.priorFor(_stateKey('btn_eat'), _btn('btn_more')), 0.9);
    });

    test('known context + absent HIGH-base candidate is SUPPRESSED, not '
        'base_weight (the "want -> I/go" bug)', () {
      // btn_i base 0.7 would glow (>= 0.50) under the old base_weight fallback.
      // It is absent from the eat row, so it caps to the 0.45 suppression floor.
      final p = ccs.priorFor(_stateKey('btn_eat'), _btn('btn_i', baseWeight: 0.7));
      expectMean(p, 0.45);
      expect(p.alpha / (p.alpha + p.beta), lessThan(0.5)); // will not glow cold
    });

    test('known context + absent LOW-base candidate keeps its (low) base', () {
      // min() never raises a low base; a 0.3 word stays 0.3 (already non-glow).
      expectMean(
        ccs.priorFor(_stateKey('btn_eat'), _btn('btn_unseen', baseWeight: 0.3)),
        0.3,
      );
    });

    test('UNKNOWN context (prev has no row) falls back to base_weight', () {
      // No row for btn_zzz -> no contextual signal -> base_weight, as before.
      expectMean(
        ccs.priorFor(_stateKey('btn_zzz'), _btn('btn_i', baseWeight: 0.7)),
        0.7,
      );
    });

    test('sentence start falls back to base_weight (no _NONE row shipped)', () {
      expectMean(
        ccs.priorFor(_stateKey(null), _btn('btn_more', baseWeight: 0.6)),
        0.6,
      );
    });
  });

  group('empty resolver == today\'s behaviour (full parity)', () {
    const empty = ContextualColdStart.empty();

    test('priorFor always equals coldStartPrior(baseWeight)', () {
      for (final w in [0.05, 0.3, 0.5, 0.7, 0.9]) {
        final prior = empty.priorFor(_stateKey('btn_eat'), _btn('b', baseWeight: w));
        final expected = coldStartPrior(w);
        expect(prior.alpha, closeTo(expected.alpha, 1e-9));
        expect(prior.beta, closeTo(expected.beta, 1e-9));
      }
    });
  });
}
