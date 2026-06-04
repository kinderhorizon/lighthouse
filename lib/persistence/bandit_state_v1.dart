/// Per-(context, button) Beta distribution for the Thompson Sampling bandit.
///
/// One row per `(stateKey, buttonId)` pair. `alpha` accumulates successful
/// taps under that context for that button; `beta` accumulates "ignored
/// while glowing" penalties (PRD § 3.2 gentle-penalty rule).
/// `observationCount` is `alpha + beta - priorPseudo` and drives the
/// observation-count-aware visual thresholds in ADR 0003.
///
/// Collection name is versioned per ADR 0005: future schema changes
/// introduce `BanditStateV2` alongside V1 and a `V1ToV2Migrator`. We do
/// NOT mutate this file's shape in place once shipped.
library;

import 'package:isar_community/isar.dart';

part 'bandit_state_v1.g.dart';

@Collection(accessor: 'banditStateV1')
class BanditStateV1 {
  Id id = Isar.autoIncrement;

  /// The full context key. Format per PRD § 3.1:
  /// "TimeBlock_DayType|WifiHash|Prev:btn_id|Context:Category".
  /// Tracked as a single string (rather than decomposed columns) so the
  /// index stays trivially correct as the key format evolves; any change
  /// becomes a V1->V2 migration regardless of column shape.
  @Index(composite: [CompositeIndex('buttonId')], unique: true, replace: true)
  late String stateKey;

  /// e.g., "btn_water". References a button id from the active board's
  /// JSON; we deliberately do NOT foreign-key into a Board collection,
  /// since boards can be Pack-Loader-imported at any time and the bandit
  /// must keep working when the parent uninstalls a sub-board.
  late String buttonId;

  /// Beta distribution alpha (successes). Includes the cold-start prior
  /// applied at insert time per ADR 0003 § Bandit prior.
  late double alpha;

  /// Beta distribution beta (failures / ignored-while-glowing).
  late double beta;

  /// Real observation count for this (stateKey, buttonId). Equal to
  /// `(alpha - priorAlpha) + (beta - priorBeta)` at any moment. Stored
  /// to keep the observation-count-aware visual thresholds (ADR 0003) a
  /// constant-time lookup rather than a derived calculation we'd have
  /// to keep priors hanging around for.
  late int observationCount;

  /// UTC instant of the most recent update. Used by future maintenance
  /// passes (compaction, stale-context pruning) and for crash log
  /// diagnostics if the bandit state ever looks suspicious.
  late DateTime updatedAt;
}
