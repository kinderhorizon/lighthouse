/// Append-only tap event log.
///
/// One row per child tap (and any other discrete event we add later).
/// The bandit updates derive from this log, so the log is the source of
/// truth; the [BanditStateV1] table is a materialized aggregate.
/// Keeping the raw log lets future versions reconstruct state from
/// scratch if a migration goes wrong, and lets the clinical lead audit
/// usage patterns during alpha without poking at derived state.
///
/// **No communication content leaks here.** `buttonId` is an internal
/// identifier; we never log `voice_out` text or `label`. The privacy
/// claim "no data ever leaves the device" still holds even if the log
/// grows large, because nothing in this table moves off-device by
/// design (no telemetry, no automatic sync; ADR 0002).
library;

import 'package:isar_community/isar.dart';

part 'raw_event_log_v1.g.dart';

@Collection(accessor: 'rawEventLogV1')
class RawEventLogV1 {
  Id id = Isar.autoIncrement;

  @Index()
  late DateTime timestamp;

  /// e.g., "tap". Stored as a string so future event types can be added
  /// without a migration (the bandit ignores unknown event types).
  late String eventType;

  late String buttonId;

  late String boardId;

  /// Snapshot of the context key at the moment of the event. Stored
  /// verbatim so the log is self-contained: a future audit doesn't need
  /// to reconstruct context.
  @Index()
  late String stateKey;

  /// Reserved, currently UNUSED, and written nowhere. HARD CONSTRAINT: if it is
  /// ever populated it must hold ONLY the same opaque, whitelisted attributes
  /// already in [stateKey] (day-type, time-bucket, wifi HASH). It must NEVER
  /// hold communication content (`voice_out` / `label`) or environmental
  /// identifiers (raw SSID, location, device names). The crash log is
  /// whitelisted by construction (ADR 0002); this free-form field is the
  /// opposite discipline, so the constraint lives here in code. Slated for
  /// removal at the next Isar schema bump (ADR 0005); not removed now because
  /// dropping a field forces an isar_community generator regen, which the
  /// frozen-schema workflow (see pubspec dev_dependencies note) keeps rare.
  String? rawContextJson;
}
