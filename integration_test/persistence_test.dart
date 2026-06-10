/// Integration tests for the Isar persistence layer.
///
/// These tests need the Isar native binary, which `isar_flutter_libs`
/// bundles into the app at build time but which is NOT present in the
/// host `flutter test` sandbox (the test binding intercepts the
/// network so Isar cannot download it on the fly).
///
/// Run via `flutter test integration_test/` against a real device or
/// emulator. The unit-testable parsing layer is covered in
/// `test/persistence/v1_fixture_loader_test.dart` so `flutter test`
/// still has full coverage of the migration-boundary logic.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/persistence/persistence.dart';

import '../test/persistence/v1_fixture_loader.dart';
import 'fixtures_inline.dart';

AACButton _btn({
  required String id,
  double baseWeight = 0.5,
}) {
  return AACButton(
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
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late Isar isar;
  late BanditRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('isar_repo_test_');
    isar = await IsarSetup.openAt(tmp, name: 'test_${tmp.path.hashCode}');
    repo = BanditRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('BanditRepository CRUD', () {
    test('round-trips a single row by (stateKey, buttonId)', () async {
      final row = BanditStateV1()
        ..stateKey = 'Morning_Weekday|wifi_H|Prev:|Context:'
        ..buttonId = 'btn_help'
        ..alpha = 3.0
        ..beta = 1.0
        ..observationCount = 4
        ..updatedAt = DateTime.utc(2026, 5, 28);
      await repo.putState(row);

      final fetched = await repo.getState(
        stateKey: 'Morning_Weekday|wifi_H|Prev:|Context:',
        buttonId: 'btn_help',
      );
      expect(fetched, isNotNull);
      expect(fetched!.alpha, 3.0);
      expect(fetched.beta, 1.0);
      expect(fetched.observationCount, 4);
    });

    test('put with same (stateKey, buttonId) replaces (composite unique)',
        () async {
      final r1 = BanditStateV1()
        ..stateKey = 'k1'
        ..buttonId = 'btn_x'
        ..alpha = 1.0
        ..beta = 1.0
        ..observationCount = 0
        ..updatedAt = DateTime.utc(2026, 5, 27);
      final r2 = BanditStateV1()
        ..stateKey = 'k1'
        ..buttonId = 'btn_x'
        ..alpha = 7.0
        ..beta = 2.0
        ..observationCount = 8
        ..updatedAt = DateTime.utc(2026, 5, 28);

      await repo.putState(r1);
      await repo.putState(r2);

      final all = await repo.getAllForState('k1');
      expect(all, hasLength(1));
      expect(all.single.alpha, 7.0);
      expect(all.single.observationCount, 8);
    });

    test('getAllForState filters to a single stateKey', () async {
      await repo.putState(BanditStateV1()
        ..stateKey = 'k1'
        ..buttonId = 'a'
        ..alpha = 1
        ..beta = 1
        ..observationCount = 0
        ..updatedAt = DateTime.utc(2026));
      await repo.putState(BanditStateV1()
        ..stateKey = 'k1'
        ..buttonId = 'b'
        ..alpha = 1
        ..beta = 1
        ..observationCount = 0
        ..updatedAt = DateTime.utc(2026));
      await repo.putState(BanditStateV1()
        ..stateKey = 'k2'
        ..buttonId = 'a'
        ..alpha = 1
        ..beta = 1
        ..observationCount = 0
        ..updatedAt = DateTime.utc(2026));

      final forK1 = await repo.getAllForState('k1');
      expect(forK1.map((r) => r.buttonId).toSet(), {'a', 'b'});
    });

    test('appendEvent persists a row', () async {
      final ev = RawEventLogV1()
        ..timestamp = DateTime.utc(2026, 5, 28)
        ..eventType = 'tap'
        ..buttonId = 'btn_help'
        ..boardId = 'core_main'
        ..stateKey = 'k1';
      await repo.appendEvent(ev);
      final all = await isar.rawEventLogV1.where().findAll();
      expect(all, hasLength(1));
      expect(all.single.buttonId, 'btn_help');
    });

    test('appendEvent prunes OLDEST-first to the trim target past the cap',
        () async {
      // One of the only two code paths that delete the child's data (review
      // item 11). Seed exactly the cap directly in one txn (appendEvent-per-row
      // would be 20k transactions); autoincrement ids run 1..cap in order.
      const cap = BanditRepository.maxRawEventRows;
      const target = BanditRepository.rawEventTrimTarget;
      final seed = <RawEventLogV1>[
        for (var i = 0; i < cap; i++)
          RawEventLogV1()
            ..timestamp = DateTime.utc(2026, 1, 1).add(Duration(seconds: i))
            ..eventType = 'tap'
            ..buttonId = 'b$i'
            ..boardId = 'core_main'
            ..stateKey = 'k',
      ];
      await isar.writeTxn(() => isar.rawEventLogV1.putAll(seed));
      expect(await isar.rawEventLogV1.where().count(), cap);

      // One more tap tips past the cap and triggers the prune.
      await repo.appendEvent(RawEventLogV1()
        ..timestamp = DateTime.utc(2026, 1, 2)
        ..eventType = 'tap'
        ..buttonId = 'newest'
        ..boardId = 'core_main'
        ..stateKey = 'k');

      // Trimmed back to the TARGET, not merely to the cap.
      expect(await isar.rawEventLogV1.where().count(), target);

      // The guard the reviewer asked for: a swapped sort direction would keep
      // the oldest and silently delete the child's MOST RECENT taps. Assert the
      // oldest (lowest ids) were the ones removed and the newest survived.
      final survivors = await isar.rawEventLogV1.where().findAll();
      final ids = survivors.map((e) => e.id).toList();
      final minId = ids.reduce(math.min);
      final maxId = ids.reduce(math.max);
      const inserted = cap + 1; // ids 1..(cap+1)
      const deleted = inserted - target; // the oldest `deleted` ids go
      expect(minId, greaterThan(deleted),
          reason: 'oldest rows (lowest ids) must be the ones deleted');
      expect(maxId, inserted,
          reason: 'the newest row must survive the prune');
      expect(survivors.any((e) => e.buttonId == 'newest'), isTrue,
          reason: 'the just-appended tap is the newest and must remain');
    });

    test('uniqueContextKeyCount counts distinct stateKey values',
        () async {
      await repo.putState(BanditStateV1()
        ..stateKey = 'k1'
        ..buttonId = 'a'
        ..alpha = 1
        ..beta = 1
        ..observationCount = 0
        ..updatedAt = DateTime.utc(2026));
      await repo.putState(BanditStateV1()
        ..stateKey = 'k1'
        ..buttonId = 'b'
        ..alpha = 1
        ..beta = 1
        ..observationCount = 0
        ..updatedAt = DateTime.utc(2026));
      await repo.putState(BanditStateV1()
        ..stateKey = 'k2'
        ..buttonId = 'a'
        ..alpha = 1
        ..beta = 1
        ..observationCount = 0
        ..updatedAt = DateTime.utc(2026));
      expect(await repo.uniqueContextKeyCount(), 2);
    });

    test('clearAll empties both collections', () async {
      await repo.putState(BanditStateV1()
        ..stateKey = 'k1'
        ..buttonId = 'a'
        ..alpha = 1
        ..beta = 1
        ..observationCount = 0
        ..updatedAt = DateTime.utc(2026));
      await repo.appendEvent(RawEventLogV1()
        ..timestamp = DateTime.utc(2026)
        ..eventType = 'tap'
        ..buttonId = 'a'
        ..boardId = 'core_main'
        ..stateKey = 'k1');
      await repo.clearAll();
      expect(await isar.banditStateV1.where().count(), 0);
      expect(await isar.rawEventLogV1.where().count(), 0);
    });
  });

  group('V1 fixture loading (ADR 0005 test fixtures)', () {
    // On-device: relative file paths do not resolve in the app sandbox,
    // so we parse the inline copies (fixtures_inline.dart) rather than
    // File('test/fixtures/...'). The host-mode unit test
    // (test/persistence/v1_fixture_loader_test.dart) parses the canonical
    // files; keep the two in sync.
    test('happy fixture loads cleanly and round-trips', () async {
      final loaded = await loadV1FixtureString(happyV1Fixture, isar);
      expect(loaded, 5);
      expect(await isar.banditStateV1.where().count(), 5);
      expect(await repo.uniqueContextKeyCount(), 5);
    });

    test('corrupted fixture surfaces FixtureLoadFailure, does NOT silently drop',
        () async {
      await expectLater(
        loadV1FixtureString(corruptedV1Fixture, isar),
        throwsA(isA<FixtureLoadFailure>()),
      );
      expect(await isar.banditStateV1.where().count(), 0,
          reason:
              'a failing migration must not leave a partial state behind');
    });

    test('max-scale: 5000 unique context keys load within reasonable time',
        () async {
      final rows = <BanditStateV1>[];
      for (var i = 0; i < 5000; i++) {
        rows.add(BanditStateV1()
          ..stateKey = 'k_$i'
          ..buttonId = 'btn_$i'
          ..alpha = 1.0
          ..beta = 1.0
          ..observationCount = 0
          ..updatedAt = DateTime.utc(2026));
      }
      final sw = Stopwatch()..start();
      await repo.putStateAll(rows);
      sw.stop();
      expect(await repo.uniqueContextKeyCount(), 5000);
      // Generous budget; tightens if it ever feels slow on a real iPad.
      expect(sw.elapsed.inSeconds, lessThan(30),
          reason: 'max-scale bulk insert took ${sw.elapsed}');
    });
  });

  group('End-to-end bandit loop', () {
    // The core acceptance check: a real sequence of taps
    // against a real Isar instance produces the expected Beta posterior,
    // and the ranker reads that state back to rank the rewarded button
    // first. Exercises BanditUpdater -> BanditRepository -> Isar ->
    // BanditRanker as one chain, no fakes.

    test('a tap persists the cold-start prior + reward to Isar', () async {
      final updater = BanditUpdater(store: repo);
      final help = _btn(id: 'btn_help', baseWeight: 0.9);

      final before = DateTime.now().toUtc();
      await updater.applyTap(stateKey: 'morning_home', tappedButton: help);

      final row = await repo.getState(
        stateKey: 'morning_home',
        buttonId: 'btn_help',
      );
      expect(row, isNotNull);
      // prior alpha 1.8 + reward 1.0 = 2.8; prior beta 0.2 unchanged.
      expect(row!.alpha, closeTo(2.8, 1e-9));
      expect(row.beta, closeTo(0.2, 1e-9));
      expect(row.observationCount, 1);
      // BanditRepository.putState stamps updatedAt at write time (it is
      // the source of truth for that field, not the updater's clock), so
      // we assert recency rather than an injected instant.
      expect(row.updatedAt.isBefore(before), isFalse);
    });

    test('repeated taps accumulate alpha; penalty accrues beta on ignored',
        () async {
      final updater = BanditUpdater(store: repo);
      final help = _btn(id: 'btn_help', baseWeight: 0.9);
      final stop = _btn(id: 'btn_stop', baseWeight: 0.9);

      // Three taps on help while stop was glowing-but-ignored each time.
      for (var i = 0; i < 3; i++) {
        await updater.applyTap(
          stateKey: 's',
          tappedButton: help,
          top3Predictions: [help, stop],
        );
      }

      final helpRow =
          await repo.getState(stateKey: 's', buttonId: 'btn_help');
      final stopRow =
          await repo.getState(stateKey: 's', buttonId: 'btn_stop');
      // help: 1.8 + 3 * 1.0 = 4.8 alpha, beta unchanged 0.2.
      expect(helpRow!.alpha, closeTo(4.8, 1e-9));
      expect(helpRow.beta, closeTo(0.2, 1e-9));
      expect(helpRow.observationCount, 3);
      // stop: ignored 3 times -> 1.8 alpha, 0.2 + 3 * 0.5 = 1.7 beta.
      expect(stopRow!.alpha, closeTo(1.8, 1e-9));
      expect(stopRow.beta, closeTo(1.7, 1e-9));
      expect(stopRow.observationCount, 3);
    });

    test('ranker reads persisted state back and ranks the winner first',
        () async {
      final updater = BanditUpdater(store: repo);
      final help = _btn(id: 'btn_help', baseWeight: 0.5);
      final stop = _btn(id: 'btn_stop', baseWeight: 0.5);
      final more = _btn(id: 'btn_more', baseWeight: 0.5);

      // Drive help strongly positive, stop/more strongly negative, so
      // the ranking is deterministic despite Thompson noise.
      for (var i = 0; i < 40; i++) {
        await updater.applyTap(
          stateKey: 's',
          tappedButton: help,
          top3Predictions: [help, stop, more],
        );
      }

      final ranker = BanditRanker(store: repo);
      final ranked = await ranker.topK(
        stateKey: 's',
        buttons: [help, stop, more],
        k: 3,
        rng: math.Random(7),
      );
      expect(ranked.first.button.id, 'btn_help');
      expect(ranked.first.observationCount, 40);
    });

    test('clearAll wipes learned state; ranker falls back to cold prior',
        () async {
      final updater = BanditUpdater(store: repo);
      final help = _btn(id: 'btn_help', baseWeight: 0.3);
      for (var i = 0; i < 10; i++) {
        await updater.applyTap(stateKey: 's', tappedButton: help);
      }
      expect(
        (await repo.getState(stateKey: 's', buttonId: 'btn_help'))!
            .observationCount,
        10,
      );

      await repo.clearAll();

      // Ranker now synthesizes the cold-start prior: observationCount 0,
      // posterior mean back to baseWeight.
      final ranker = BanditRanker(store: repo);
      final ranked = await ranker.topK(
        stateKey: 's',
        buttons: [help],
        k: 1,
        rng: math.Random(1),
      );
      expect(ranked.single.observationCount, 0);
      expect(ranked.single.posteriorMean, closeTo(0.3, 1e-9));
    });
  });

  group('MigrationChain', () {
    test('empty chain at V1 baseline returns MigrationSuccess', () async {
      final result = await const MigrationChain([]).run(isar);
      expect(result, isA<MigrationSuccess>());
    });

    test('chain stops on first failure', () async {
      final fail = _FailingMigrator();
      final result = await MigrationChain([fail]).run(isar);
      expect(result, isA<MigrationFailure>());
      expect((result as MigrationFailure).reason, contains('intentional'));
    });
  });
}

class _FailingMigrator extends SchemaMigrator {
  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  Future<MigrationResult> migrate(Isar isar) async {
    return const MigrationFailure(
      reason: 'intentional failure for test',
      diagnostics: {'cause': 'unit test'},
    );
  }
}
