/// Narrow read/write surface the bandit updater talks to.
///
/// In production [BanditRepository] (lib/persistence/) implements this.
/// In unit tests we use a fake backed by an in-memory map, which keeps
/// the updater's logic testable without a live Isar instance.
library;

import '../../persistence/persistence.dart';

abstract class BanditStore {
  Future<BanditStateV1?> getState({
    required String stateKey,
    required String buttonId,
  });

  /// Every row whose `stateKey` matches, in one read. The ranker uses
  /// this to score all candidate buttons for a context with a single
  /// query instead of one [getState] per button.
  Future<List<BanditStateV1>> getAllForState(String stateKey);

  Future<void> putState(BanditStateV1 row);

  /// Upserts several rows in a SINGLE transaction. The per-tap update writes
  /// the winner plus up to three penalised predictions; routing them through
  /// one write avoids N+1 write transactions on low-end tablets (the read path
  /// already batches via [getAllForState]).
  Future<void> putStateAll(List<BanditStateV1> rows);
}
