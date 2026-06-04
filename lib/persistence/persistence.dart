/// Persistence barrel.
///
/// Isar collections (BanditStateV1, RawEventLogV1) and the
/// SchemaMigrator chain. See docs/adr/0005-isar-schema-versioning.md.
///
/// Migration code is the highest-risk code in this codebase by impact:
/// its failure mode is silent destruction of a non-speaking child's
/// weeks of communication learning. Strictest review, strictest test
/// coverage.
library;

export 'bandit_repository.dart';
export 'bandit_state_v1.dart';
export 'isar_setup.dart';
export 'raw_event_log_v1.dart';
export 'schema_migrator.dart';
