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

AACButton _btn({
  required String id,
  AACButtonType type = AACButtonType.word,
  double baseWeight = 0.5,
}) {
  return AACButton(
    id: id,
    label: id,
    labelByLocale: const {},
    type: type,
    position: (row: 0, col: 0),
    category: 'needs',
    baseWeight: baseWeight,
    iconUri: '',
    voiceOut: id,
  );
}

void main() {
  group('BanditRanker.topK', () {
    test('excludes folders from the candidate set', () async {
      final store = _FakeStore();
      final ranker = BanditRanker(store: store);
      final word = _btn(id: 'btn_help', baseWeight: 0.9);
      final folder = _btn(
        id: 'btn_food',
        type: AACButtonType.folder,
        baseWeight: 0.9,
      );
      final ranked = await ranker.topK(
        stateKey: 's1',
        buttons: [word, folder],
        k: 3,
        rng: math.Random(0),
      );
      expect(ranked.length, 1);
      expect(ranked.single.button.id, 'btn_help');
    });

    test('returns empty when no non-folder candidates remain', () async {
      final ranker = BanditRanker(store: _FakeStore());
      final ranked = await ranker.topK(
        stateKey: 's1',
        buttons: [_btn(id: 'btn_food', type: AACButtonType.folder)],
        k: 3,
        rng: math.Random(0),
      );
      expect(ranked, isEmpty);
    });

    test('cold-start: synthesizes prior from baseWeight, observationCount=0',
        () async {
      final ranker = BanditRanker(store: _FakeStore());
      final btn = _btn(id: 'btn_help', baseWeight: 0.9);
      final ranked = await ranker.topK(
        stateKey: 's1',
        buttons: [btn],
        k: 1,
        rng: math.Random(0),
      );
      expect(ranked.single.observationCount, 0);
      // Posterior mean reflects the cold-start prior: 1.8 / (1.8 + 0.2).
      expect(ranked.single.posteriorMean, closeTo(0.9, 1e-9));
    });

    test('existing row wins over synthetic prior on observation count',
        () async {
      final store = _FakeStore();
      store.seed(
        stateKey: 's1',
        buttonId: 'btn_help',
        alpha: 10.0,
        beta: 1.0,
        observationCount: 9,
      );
      final ranker = BanditRanker(store: store);
      final ranked = await ranker.topK(
        stateKey: 's1',
        buttons: [_btn(id: 'btn_help', baseWeight: 0.1)],
        k: 1,
        rng: math.Random(0),
      );
      expect(ranked.single.observationCount, 9);
      // Posterior mean uses the row's alpha/beta, NOT baseWeight=0.1.
      expect(ranked.single.posteriorMean, closeTo(10.0 / 11.0, 1e-9));
    });

    test('topK truncates and orders by sampled draw, descending', () async {
      final store = _FakeStore();
      // Make button A overwhelmingly favored (alpha 100, beta 1) and
      // buttons B/C overwhelmingly unfavored. Thompson sampling is
      // stochastic, but at these concentrations the top draw is A with
      // probability ~ 1.
      store.seed(
          stateKey: 's1',
          buttonId: 'a',
          alpha: 100.0,
          beta: 1.0,
          observationCount: 100);
      store.seed(
          stateKey: 's1',
          buttonId: 'b',
          alpha: 1.0,
          beta: 100.0,
          observationCount: 100);
      store.seed(
          stateKey: 's1',
          buttonId: 'c',
          alpha: 1.0,
          beta: 100.0,
          observationCount: 100);
      final ranker = BanditRanker(store: store);
      final ranked = await ranker.topK(
        stateKey: 's1',
        buttons: [
          _btn(id: 'a'),
          _btn(id: 'b'),
          _btn(id: 'c'),
        ],
        k: 2,
        rng: math.Random(5),
      );
      expect(ranked.length, 2);
      expect(ranked.first.button.id, 'a');
      // Top-2 draws are non-increasing.
      expect(ranked[0].draw, greaterThanOrEqualTo(ranked[1].draw));
    });

    test('k <= 0 returns empty', () async {
      final ranker = BanditRanker(store: _FakeStore());
      final ranked = await ranker.topK(
        stateKey: 's1',
        buttons: [_btn(id: 'a')],
        k: 0,
        rng: math.Random(0),
      );
      expect(ranked, isEmpty);
    });

    test('seeded RNG produces deterministic ranking', () async {
      // Two ranker calls against identical state with identically-seeded
      // RNGs must produce the same ordering. This is the contract the
      // integration test relies on.
      Future<List<String>> run() async {
        final store = _FakeStore();
        store.seed(
            stateKey: 's',
            buttonId: 'a',
            alpha: 3.0,
            beta: 1.0,
            observationCount: 3);
        store.seed(
            stateKey: 's',
            buttonId: 'b',
            alpha: 2.0,
            beta: 2.0,
            observationCount: 4);
        store.seed(
            stateKey: 's',
            buttonId: 'c',
            alpha: 1.5,
            beta: 1.5,
            observationCount: 3);
        final ranker = BanditRanker(store: store);
        final ranked = await ranker.topK(
          stateKey: 's',
          buttons: [_btn(id: 'a'), _btn(id: 'b'), _btn(id: 'c')],
          k: 3,
          rng: math.Random(2026),
        );
        return ranked.map((p) => p.button.id).toList();
      }

      expect(await run(), await run());
    });
  });
}
