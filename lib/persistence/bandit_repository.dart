/// Read/write surface for bandit state and the raw event log.
///
/// All Isar access lives behind this repository. The bandit logic and
/// the tap event logger never touch Isar directly. This is the file
/// that gets stricter review per ADR 0005's "highest-risk code in the
/// codebase by impact" framing.
library;

import 'package:isar_community/isar.dart';

import '../logic/bandit/bandit_store.dart';
import '../logic/favourites/favourite_ranking.dart';
import 'bandit_state_v1.dart';
import 'raw_event_log_v1.dart';

class BanditRepository implements BanditStore {
  BanditRepository(this._isar);

  final Isar _isar;

  /// Looks up the Beta distribution row for `(stateKey, buttonId)`.
  /// Returns null if no row exists (caller should treat as "cold prior
  /// will apply when we first see this combination").
  Future<BanditStateV1?> getState({
    required String stateKey,
    required String buttonId,
  }) {
    return _isar.banditStateV1.getByStateKeyButtonId(stateKey, buttonId);
  }

  /// Returns every row whose `stateKey` matches. Used by the ranking
  /// step to score every button for the current context.
  Future<List<BanditStateV1>> getAllForState(String stateKey) {
    return _isar.banditStateV1
        .filter()
        .stateKeyEqualTo(stateKey)
        .findAll();
  }

  /// Upserts a row. Composite unique index on (stateKey, buttonId) is
  /// declared with `replace: true`, so a put with a colliding key
  /// overwrites the existing row in a single transaction.
  Future<void> putState(BanditStateV1 row) async {
    row.updatedAt = DateTime.now().toUtc();
    await _isar.writeTxn(() async {
      await _isar.banditStateV1.putByStateKeyButtonId(row);
    });
  }

  /// Bulk upsert. Used by the migration chain when V(N+1) rows are
  /// materialized from V(N).
  Future<void> putStateAll(List<BanditStateV1> rows) async {
    final now = DateTime.now().toUtc();
    for (final r in rows) {
      r.updatedAt = now;
    }
    await _isar.writeTxn(() async {
      await _isar.banditStateV1.putAllByStateKeyButtonId(rows);
    });
  }

  /// Hard cap on raw tap-log rows, with a lower target to trim back to so the
  /// (relatively expensive) prune runs rarely, not on every overflowing tap.
  /// One row per tap, forever, with the only prior deletion being the parent's
  /// full "Reset learned state": at ~300-800 taps/day a long-lived single-device
  /// install would grow without bound, and topTappedButtons materializes the
  /// whole table, so an unbounded log slides from multi-second jank into OOM
  /// territory on a 2 GB tablet over a year or two. A rolling window of the most
  /// recent taps is ample for the favourites-frequency ranking (which favours
  /// recent usage anyway) and privacy-neutral: same on-device data, just pruned.
  static const int maxRawEventRows = 20000;
  static const int rawEventTrimTarget = 15000;

  /// Append a tap event to the raw log. Fire-and-forget from the
  /// caller's perspective; the future completes when the row is durable.
  Future<void> appendEvent(RawEventLogV1 event) async {
    await _isar.writeTxn(() async {
      await _isar.rawEventLogV1.put(event);
      final count = await _isar.rawEventLogV1.count();
      if (count > maxRawEventRows) {
        // Delete the oldest rows (lowest autoIncrement ids, oldest taps) down to
        // the target. anyId() iterates the id index ascending, so limit() takes
        // the oldest first.
        final oldestIds = await _isar.rawEventLogV1
            .where()
            .anyId()
            .limit(count - rawEventTrimTarget)
            .idProperty()
            .findAll();
        await _isar.rawEventLogV1.deleteAll(oldestIds);
      }
    });
  }

  /// Most-tapped buttons across all contexts, top [limit], for the
  /// favourites suggestion surface (ADR 0013). Aggregation is the pure
  /// [rankByFrequency]; this is just the Isar read that feeds it. Called on
  /// demand from the parental editor, never on the home hot path.
  Future<List<ButtonRef>> topTappedButtons({required int limit}) async {
    final taps =
        await _isar.rawEventLogV1.filter().eventTypeEqualTo('tap').findAll();
    return rankByFrequency(
      taps.map((e) => (boardId: e.boardId, buttonId: e.buttonId)),
      limit: limit,
    );
  }

  /// Count of distinct stateKeys, the cardinality figure that appears
  /// in crash logs per ADR 0002 (`unique_context_keys_count`).
  Future<int> uniqueContextKeyCount() async {
    // Fetch only the deduplicated stateKey strings, not whole BanditStateV1 rows
    // (alpha/beta/updatedAt), just to count distinct keys. This runs at launch
    // for the crash-log diagnostic, so it must stay cheap as the table grows
    // (review item 13).
    final keys = await _isar.banditStateV1
        .where()
        .distinctByStateKey()
        .stateKeyProperty()
        .findAll();
    return keys.length;
  }

  /// Approximate on-disk size in bytes. Surfaced in crash logs per ADR
  /// 0002 (`isar_db_size_bytes`).
  Future<int> approximateSizeBytes() async {
    return _isar.getSize();
  }

  /// Test-time / "Reset learned state" clear. Wipes both collections in
  /// a single transaction; the parent invokes this from Settings >
  /// Advanced > Reset learned state once Phase 3 wires the UI.
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.banditStateV1.clear();
      await _isar.rawEventLogV1.clear();
    });
  }
}
