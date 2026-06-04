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

  int putStateCalls = 0;
  int putStateAllCalls = 0;

  @override
  Future<void> putState(BanditStateV1 row) async {
    putStateCalls++;
    _rows[_key(row.stateKey, row.buttonId)] = row;
  }

  @override
  Future<void> putStateAll(List<BanditStateV1> rows) async {
    putStateAllCalls++;
    for (final row in rows) {
      _rows[_key(row.stateKey, row.buttonId)] = row;
    }
  }
}

AACButton _btn({
  required String id,
  required String category,
  double baseWeight = 0.5,
}) {
  return AACButton(
    id: id,
    label: id,
    labelByLocale: const {},
    type: AACButtonType.word,
    position: (row: 0, col: 0),
    category: category,
    baseWeight: baseWeight,
    iconUri: '',
    voiceOut: id,
  );
}

void main() {
  group('BanditUpdater.applyTap (PRD 3.2 + ADR 0003 cold-start)', () {
    test('first tap on a fresh (state, button): cold-start prior + 1.0 reward',
        () async {
      final store = _FakeStore();
      final updater = BanditUpdater(
        store: store,
        clock: () => DateTime.utc(2026, 5, 28, 12),
      );
      final btn = _btn(id: 'btn_help', category: 'needs', baseWeight: 0.9);

      await updater.applyTap(stateKey: 's1', tappedButton: btn);

      final row = await store.getState(stateKey: 's1', buttonId: 'btn_help');
      expect(row, isNotNull);
      // Prior: alpha = 2 * 0.9 = 1.8, beta = 2 * 0.1 = 0.2.
      // After winner reward: alpha += 1.0 -> 2.8.
      expect(row!.alpha, closeTo(2.8, 1e-9));
      expect(row.beta, closeTo(0.2, 1e-9));
      // observationCount counts REAL observations only; prior is not
      // counted. First real observation -> 1.
      expect(row.observationCount, 1);
      expect(row.updatedAt, DateTime.utc(2026, 5, 28, 12));
    });

    test('second tap on same (state, button) increments alpha by 1, '
        'observationCount stays as a real-observation counter', () async {
      final store = _FakeStore();
      final updater = BanditUpdater(store: store);
      final btn = _btn(id: 'btn_help', category: 'needs', baseWeight: 0.9);

      await updater.applyTap(stateKey: 's1', tappedButton: btn);
      await updater.applyTap(stateKey: 's1', tappedButton: btn);

      final row =
          await store.getState(stateKey: 's1', buttonId: 'btn_help');
      // Prior 1.8 + 1.0 + 1.0 = 3.8.
      expect(row!.alpha, closeTo(3.8, 1e-9));
      expect(row.beta, closeTo(0.2, 1e-9));
      expect(row.observationCount, 2);
    });

    test('different state keys are independent rows', () async {
      final store = _FakeStore();
      final updater = BanditUpdater(store: store);
      final btn = _btn(id: 'btn_help', category: 'needs');

      await updater.applyTap(stateKey: 'morning_home', tappedButton: btn);
      await updater.applyTap(stateKey: 'school_lunch', tappedButton: btn);

      final morning = await store.getState(
          stateKey: 'morning_home', buttonId: 'btn_help');
      final school = await store.getState(
          stateKey: 'school_lunch', buttonId: 'btn_help');
      expect(morning, isNotNull);
      expect(school, isNotNull);
      expect(morning!.observationCount, 1);
      expect(school!.observationCount, 1);
    });

    test('penalty branch applies +0.5 beta to ignored predictions only',
        () async {
      final store = _FakeStore();
      final updater = BanditUpdater(store: store);
      final winner =
          _btn(id: 'btn_help', category: 'needs', baseWeight: 0.9);
      final ignoredA =
          _btn(id: 'btn_stop', category: 'needs', baseWeight: 0.9);
      final ignoredB =
          _btn(id: 'btn_more', category: 'modifier', baseWeight: 0.7);

      await updater.applyTap(
        stateKey: 's1',
        tappedButton: winner,
        top3Predictions: [winner, ignoredA, ignoredB],
      );

      final winnerRow =
          await store.getState(stateKey: 's1', buttonId: 'btn_help');
      final stopRow =
          await store.getState(stateKey: 's1', buttonId: 'btn_stop');
      final moreRow =
          await store.getState(stateKey: 's1', buttonId: 'btn_more');

      // Winner: prior + 1.0 reward, no penalty (the prediction == winner
      // branch is skipped).
      expect(winnerRow!.alpha, closeTo(2.8, 1e-9));
      expect(winnerRow.beta, closeTo(0.2, 1e-9));
      expect(winnerRow.observationCount, 1);

      // Stop: prior alpha 1.8, beta 0.2 + 0.5 = 0.7.
      expect(stopRow!.alpha, closeTo(1.8, 1e-9));
      expect(stopRow.beta, closeTo(0.7, 1e-9));
      expect(stopRow.observationCount, 1);

      // More: prior alpha 1.4, beta 0.6 + 0.5 = 1.1.
      expect(moreRow!.alpha, closeTo(1.4, 1e-9));
      expect(moreRow.beta, closeTo(1.1, 1e-9));
      expect(moreRow.observationCount, 1);
    });

    test('winner + penalties are written in a single batched call (no N+1)',
        () async {
      final store = _FakeStore();
      final updater = BanditUpdater(store: store);
      final winner = _btn(id: 'btn_help', category: 'needs', baseWeight: 0.9);
      final ignoredA = _btn(id: 'btn_stop', category: 'needs');
      final ignoredB = _btn(id: 'btn_more', category: 'modifier');

      await updater.applyTap(
        stateKey: 's1',
        tappedButton: winner,
        top3Predictions: [winner, ignoredA, ignoredB],
      );

      // One batched write covers the winner + both penalties; the per-row
      // putState path is not used (M2: no N+1 write transactions per tap).
      expect(store.putStateAllCalls, 1);
      expect(store.putStateCalls, 0);
    });

    test('empty top3 makes applyTap a pure reward (Phase 2 default)',
        () async {
      final store = _FakeStore();
      final updater = BanditUpdater(store: store);
      final btn = _btn(id: 'btn_help', category: 'needs', baseWeight: 0.9);

      await updater.applyTap(
        stateKey: 's1',
        tappedButton: btn,
        top3Predictions: const [],
      );

      // Only one row exists; no penalty side effects on any other id.
      final row =
          await store.getState(stateKey: 's1', buttonId: 'btn_help');
      expect(row!.alpha, closeTo(2.8, 1e-9));
      expect(row.beta, closeTo(0.2, 1e-9));
    });

    test('tap == prediction does NOT double-penalize', () async {
      final store = _FakeStore();
      final updater = BanditUpdater(store: store);
      final btn = _btn(id: 'btn_help', category: 'needs', baseWeight: 0.9);

      await updater.applyTap(
        stateKey: 's1',
        tappedButton: btn,
        top3Predictions: [btn, btn, btn],
      );

      final row =
          await store.getState(stateKey: 's1', buttonId: 'btn_help');
      // Only the winner reward (+1.0); no beta increment for the
      // self-matching predictions.
      expect(row!.alpha, closeTo(2.8, 1e-9));
      expect(row.beta, closeTo(0.2, 1e-9));
      expect(row.observationCount, 1);
    });
  });
}
