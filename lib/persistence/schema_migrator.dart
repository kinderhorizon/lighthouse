/// Schema migration plumbing (ADR 0005).
///
/// The collection name is the schema version (BanditStateV1, V2, ...).
/// A migration from N to N+1 creates the V(N+1) collection alongside
/// V(N), copies rows over with the new shape, and only deletes V(N)
/// once the parent confirms via the "Start fresh" path.
///
/// Failed migrations MUST NOT silently wipe state. The chain stops on
/// first failure and the UI shows the parent a modal letting them
/// choose between "Keep old data" (read-only mount of the previous
/// version) and "Start fresh". This file provides the plumbing; the
/// UI surface lands when the first V1->V2 migration is needed.
library;

import 'package:isar_community/isar.dart';

sealed class MigrationResult {
  const MigrationResult();
}

class MigrationSuccess extends MigrationResult {
  const MigrationSuccess({this.rowsMigrated = 0});
  final int rowsMigrated;
}

class MigrationFailure extends MigrationResult {
  const MigrationFailure({
    required this.reason,
    this.diagnostics = const {},
  });

  final String reason;
  final Map<String, dynamic> diagnostics;

  @override
  String toString() => 'MigrationFailure($reason, diagnostics=$diagnostics)';
}

abstract class SchemaMigrator {
  int get fromVersion;
  int get toVersion;
  Future<MigrationResult> migrate(Isar isar);
}

/// Runs an ordered list of migrators (V1->V2, V2->V3, ...) sequentially,
/// stopping on first failure. Returns the result of the last attempted
/// migration; [MigrationSuccess] means every migrator in the chain
/// succeeded.
///
/// For Phase 2 V1 baseline, the chain is empty: there is no V0->V1 step
/// because V1 is the starting point. The chain runner is in place so
/// the first V1->V2 work is just "add a migrator and append it to the
/// list", not "build the chain infrastructure from scratch".
class MigrationChain {
  const MigrationChain(this.migrators);

  final List<SchemaMigrator> migrators;

  Future<MigrationResult> run(Isar isar) async {
    for (final m in migrators) {
      final result = await m.migrate(isar);
      if (result is MigrationFailure) return result;
    }
    return const MigrationSuccess();
  }
}
