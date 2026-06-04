/// Regression coverage for the cold-start prior clamp (review finding #1).
///
/// An imported pack is untrusted (ADR 0015). Before the fix, AACButton accepted
/// base_weight in [0, 1e6]; the cold-start prior `beta = 2 * (1 - w)` then went
/// negative for `w > 1`, the Beta sampler returned NaN, and NaN sorts ABOVE
/// every real value in the ranker's descending sort, pinning a crafted button
/// to the top of the suggestions over genuinely-learned buttons. These tests
/// pin all four layers of the fix:
///   (a) parse now rejects > 1.0           -> board_import_validation_test.dart
///   (b) the ranker draws finite/bounded even for an out-of-range weight that
///       bypassed parse (proves the clamp is the belt, not just the parse)
///   (c) an out-of-range / endpoint button is not NaN-pinned above a learned
///       button (every draw stays in [0, 1])
///   (d) the ranker and the updater seed from the SAME prior, so a button is
///       never ranked under one prior and learned under another
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/persistence/persistence.dart';

class _FakeStore implements BanditStore {
  final Map<String, BanditStateV1> _rows = {};

  String _key(String s, String b) => '$s|$b';

  @override
  Future<BanditStateV1?> getState({
    required String stateKey,
    required String buttonId,
  }) async =>
      _rows[_key(stateKey, buttonId)];

  @override
  Future<List<BanditStateV1>> getAllForState(String stateKey) async =>
      _rows.values.where((r) => r.stateKey == stateKey).toList();

  @override
  Future<void> putState(BanditStateV1 row) async {
    _rows[_key(row.stateKey, row.buttonId)] = row;
  }

  @override
  Future<void> putStateAll(List<BanditStateV1> rows) async {
    for (final row in rows) {
      _rows[_key(row.stateKey, row.buttonId)] = row;
    }
  }

  void seed({
    required String stateKey,
    required String buttonId,
    required double alpha,
    required double beta,
    int observationCount = 0,
  }) {
    _rows[_key(stateKey, buttonId)] = BanditStateV1()
      ..stateKey = stateKey
      ..buttonId = buttonId
      ..alpha = alpha
      ..beta = beta
      ..observationCount = observationCount
      ..updatedAt = DateTime.utc(2026, 5, 28);
  }
}

/// Constructs a button DIRECTLY (no JSON parse), so an out-of-range base_weight
/// can be injected to prove the runtime clamp, not just the parse bound.
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

void main() {
  group('coldStartPrior', () {
    test('maps a normal weight to 2w / 2(1 - w)', () {
      final p = coldStartPrior(0.3);
      expect(p.alpha, closeTo(0.6, 1e-9));
      expect(p.beta, closeTo(1.4, 1e-9));
    });

    test('clamps endpoint 1.0 to a strictly-positive, finite beta', () {
      final p = coldStartPrior(1.0);
      expect(p.beta, greaterThan(0.0));
      expect(p.beta.isFinite, isTrue);
      expect(p.alpha.isFinite, isTrue);
    });

    test('clamps endpoint 0.0 to a strictly-positive, finite alpha', () {
      final p = coldStartPrior(0.0);
      expect(p.alpha, greaterThan(0.0));
      expect(p.alpha.isFinite, isTrue);
      expect(p.beta.isFinite, isTrue);
    });

    test('clamps an out-of-range weight (> 1) to finite, positive params', () {
      final p = coldStartPrior(2.0);
      expect(p.alpha, greaterThan(0.0));
      expect(p.beta, greaterThan(0.0));
      expect(p.alpha.isFinite, isTrue);
      expect(p.beta.isFinite, isTrue);
    });

    test('falls back to the neutral 0.5 prior for a non-finite weight', () {
      final p = coldStartPrior(double.nan);
      expect(p.alpha, closeTo(1.0, 1e-9));
      expect(p.beta, closeTo(1.0, 1e-9));
    });
  });

  group('BanditRanker anti-pinning (layers b + c)', () {
    // A fixed seed makes the draw deterministic; the assertion is on finiteness
    // and bounds, which is exactly the property NaN violates (NaN is neither
    // finite nor <= 1.0, and it sorts above every real draw).
    for (final w in [2.0, 1.0, 0.0, 1e6]) {
      test('out-of-range/endpoint base_weight $w yields a finite [0,1] draw',
          () async {
        final ranker = BanditRanker(store: _FakeStore());
        final result = await ranker.topK(
          stateKey: 's',
          buttons: [_btn('crafted', baseWeight: w)],
          k: 1,
          rng: math.Random(7),
        );
        expect(result, hasLength(1));
        final draw = result.single.draw;
        expect(draw.isFinite, isTrue, reason: 'a NaN draw would not be finite');
        expect(draw, inInclusiveRange(0.0, 1.0),
            reason: 'a NaN draw would sort above every learned button');
      });
    }

    test('a corrupt/legacy persisted row falls back to the cold-start prior',
        () async {
      // A row persisted under the pre-clamp formula (or via Isar corruption)
      // could carry a non-positive Beta param that would NaN the sampler. The
      // ranker must treat such a row as cold-start, not feed it through. Both
      // writers clamp now, so this guards pre-fix / corrupted state only.
      final store = _FakeStore();
      store.seed(stateKey: 's', buttonId: 'corrupt', alpha: 2.0, beta: -1.0);
      final ranker = BanditRanker(store: store);
      final result = await ranker.topK(
        stateKey: 's',
        buttons: [_btn('corrupt', baseWeight: 0.5)],
        k: 1,
        rng: math.Random(3),
      );
      expect(result, hasLength(1));
      expect(result.single.draw.isFinite, isTrue);
      expect(result.single.draw, inInclusiveRange(0.0, 1.0));
    });

    test('a crafted out-of-range button never pins the sort with a NaN draw',
        () async {
      final store = _FakeStore();
      // A button with real, confident learning alongside the crafted one.
      store.seed(stateKey: 's', buttonId: 'learned', alpha: 30.0, beta: 3.0);
      final ranker = BanditRanker(store: store);
      // The anti-pinning guarantee is structural, not statistical: NaN sorts
      // above every value in the descending sort, so the bug manifests as a
      // non-finite or out-of-[0,1] draw reaching the ranked list. A strongly
      // weighted button legitimately outranking a learned one is correct, so
      // we assert ONLY that every returned draw is a real number in [0, 1]
      // across many seeds (pre-fix the crafted row's draw is NaN and fails).
      for (var seed = 0; seed < 50; seed++) {
        final result = await ranker.topK(
          stateKey: 's',
          buttons: [
            _btn('crafted', baseWeight: 5.0),
            _btn('learned', baseWeight: 0.5),
          ],
          k: 2,
          rng: math.Random(seed),
        );
        expect(result, hasLength(2));
        for (final r in result) {
          expect(r.draw.isFinite, isTrue,
              reason: 'NaN would not be finite (seed $seed)');
          expect(r.draw, inInclusiveRange(0.0, 1.0),
              reason: 'NaN would sort above every real draw (seed $seed)');
        }
        // Descending order with finite values: the top is a real draw, not a
        // NaN floated above the learned button.
        expect(result.first.draw, greaterThanOrEqualTo(result.last.draw));
      }
    });
  });

  group('ranker and updater share one prior (layer d)', () {
    test('the updater seeds the cold-start row from coldStartPrior', () async {
      final store = _FakeStore();
      final updater = BanditUpdater(
        store: store,
        clock: () => DateTime.utc(2026, 5, 28),
      );
      // First-ever tap of this button seeds the cold-start row, then applies
      // the +1 reward to alpha. So the persisted row is the shared prior plus
      // the reward, proving the updater routed through coldStartPrior.
      await updater.applyTap(stateKey: 's', tappedButton: _btn('w', baseWeight: 0.3));
      final row = await store.getState(stateKey: 's', buttonId: 'w');
      final prior = coldStartPrior(0.3);
      expect(row, isNotNull);
      expect(row!.alpha, closeTo(prior.alpha + 1.0, 1e-9));
      expect(row.beta, closeTo(prior.beta, 1e-9));
    });

    test('an out-of-range weight persists a finite row (no NaN on disk)',
        () async {
      final store = _FakeStore();
      final updater = BanditUpdater(
        store: store,
        clock: () => DateTime.utc(2026, 5, 28),
      );
      await updater.applyTap(stateKey: 's', tappedButton: _btn('w', baseWeight: 9.0));
      final row = await store.getState(stateKey: 's', buttonId: 'w');
      expect(row, isNotNull);
      expect(row!.alpha.isFinite, isTrue);
      expect(row.beta, greaterThan(0.0));
      expect(row.beta.isFinite, isTrue);
    });
  });

  group('ranker and updater agree under ContextualColdStart (layer d, '
      'context-aware)', () {
    // A real-shaped stateKey carrying the previous button. Both the ranker (no-
    // row scoring) and the updater (seeding a fresh row) parse Prev:btn_eat out
    // of THIS same key, so they resolve the same (prev, cand) mean.
    const stateKey =
        'Morning_Weekday|wifi_UNKNOWN|Prev:btn_eat|Context:food';
    final ccs = ContextualColdStart(const {
      'btn_eat': {'btn_more': 0.9}, // contextual override; absent for others
    });

    test('the ranker scores a no-row button under the context-aware mean',
        () async {
      final ranker = BanditRanker(store: _FakeStore(), coldStart: ccs);
      final result = await ranker.topK(
        stateKey: stateKey,
        buttons: [_btn('btn_more', baseWeight: 0.3)], // base 0.3 must be ignored
        k: 1,
        rng: math.Random(1),
      );
      // posteriorMean is alpha/(alpha+beta), independent of the random draw.
      // 0.9 (the override), not 0.3 (the base_weight).
      expect(result.single.posteriorMean, closeTo(0.9, 1e-9));
      expect(result.single.observationCount, 0);
    });

    test('the updater seeds the fresh row from the SAME context-aware prior',
        () async {
      final store = _FakeStore();
      final updater = BanditUpdater(
        store: store,
        coldStart: ccs,
        clock: () => DateTime.utc(2026, 5, 28),
      );
      await updater.applyTap(
        stateKey: stateKey,
        tappedButton: _btn('btn_more', baseWeight: 0.3),
      );
      final row = await store.getState(stateKey: stateKey, buttonId: 'btn_more');
      // Seeded from coldStartPrior(0.9), then +1 reward on alpha.
      final prior = ccs.priorFor(stateKey, _btn('btn_more', baseWeight: 0.3));
      expect(row!.alpha, closeTo(prior.alpha + 1.0, 1e-9));
      expect(row.beta, closeTo(prior.beta, 1e-9));
    });

    test('ranker pre-obs mean and updater seed are the IDENTICAL Beta', () async {
      final btn = _btn('btn_more', baseWeight: 0.3);
      final shared = ccs.priorFor(stateKey, btn);

      final ranker = BanditRanker(store: _FakeStore(), coldStart: ccs);
      final ranked = await ranker.topK(
        stateKey: stateKey,
        buttons: [btn],
        k: 1,
        rng: math.Random(5),
      );
      // Ranker's posterior mean == the shared prior's mean.
      expect(
        ranked.single.posteriorMean,
        closeTo(shared.alpha / (shared.alpha + shared.beta), 1e-9),
      );

      final store = _FakeStore();
      final updater = BanditUpdater(
        store: store,
        coldStart: ccs,
        clock: () => DateTime.utc(2026, 5, 28),
      );
      await updater.applyTap(stateKey: stateKey, tappedButton: btn);
      final row = await store.getState(stateKey: stateKey, buttonId: 'btn_more');
      // Updater seeded the same Beta (minus the +1 reward it then applied).
      expect(row!.alpha - 1.0, closeTo(shared.alpha, 1e-9));
      expect(row.beta, closeTo(shared.beta, 1e-9));
    });

    test('a high-base candidate ABSENT from a known context row is suppressed, '
        'NOT surfaced on base_weight (ranker + updater agree)', () async {
      // btn_happy base 0.7 would glow (>= 0.50 shimmer) under the old absent ->
      // base_weight rule. It is absent from the btn_eat row, so it caps to the
      // 0.45 suppression floor in BOTH the ranker and the updater. This is the
      // "want -> I/go" class of bug: gated words must not glow on intrinsic
      // weight in a context the model scored.
      final btn = _btn('btn_happy', baseWeight: 0.7);
      final suppressed = coldStartPrior(0.45); // min(0.7, 0.45) floor

      final ranker = BanditRanker(store: _FakeStore(), coldStart: ccs);
      final ranked = await ranker.topK(
        stateKey: stateKey,
        buttons: [btn],
        k: 1,
        rng: math.Random(2),
      );
      expect(ranked.single.posteriorMean, closeTo(0.45, 1e-9));
      expect(ranked.single.posteriorMean, lessThan(0.5)); // will not glow cold

      final store = _FakeStore();
      final updater = BanditUpdater(
        store: store,
        coldStart: ccs,
        clock: () => DateTime.utc(2026, 5, 28),
      );
      await updater.applyTap(stateKey: stateKey, tappedButton: btn);
      final row = await store.getState(stateKey: stateKey, buttonId: 'btn_happy');
      // Updater seeded from the SAME suppressed prior, then +1 reward on alpha.
      expect(row!.alpha, closeTo(suppressed.alpha + 1.0, 1e-9));
      expect(row.beta, closeTo(suppressed.beta, 1e-9));
    });

    test('an UNKNOWN context (prev not in the artifact) still uses base_weight',
        () async {
      // No row for this prev -> no contextual signal -> base_weight, unchanged.
      const unknownPrevKey =
          'Morning_Weekday|wifi_UNKNOWN|Prev:btn_nosuchprev|Context:';
      final ranker = BanditRanker(store: _FakeStore(), coldStart: ccs);
      final ranked = await ranker.topK(
        stateKey: unknownPrevKey,
        buttons: [_btn('btn_happy', baseWeight: 0.7)],
        k: 1,
        rng: math.Random(2),
      );
      expect(ranked.single.posteriorMean, closeTo(0.7, 1e-9));
    });

    test('a learned row still wins over the prior (prior governs no-row only)',
        () async {
      // Seed a confident learned row for btn_more; the context-aware prior must
      // NOT override an existing row (it only seeds/scores no-row buttons).
      final store = _FakeStore();
      store.seed(
        stateKey: stateKey,
        buttonId: 'btn_more',
        alpha: 40.0,
        beta: 2.0,
        observationCount: 41,
      );
      final ranker = BanditRanker(store: store, coldStart: ccs);
      final ranked = await ranker.topK(
        stateKey: stateKey,
        buttons: [_btn('btn_more', baseWeight: 0.3)],
        k: 1,
        rng: math.Random(9),
      );
      // Learned mean 40/42 ~ 0.952, NOT the prior's 0.9; obs reflects learning.
      expect(ranked.single.posteriorMean, closeTo(40.0 / 42.0, 1e-9));
      expect(ranked.single.observationCount, 41);
    });
  });
}
