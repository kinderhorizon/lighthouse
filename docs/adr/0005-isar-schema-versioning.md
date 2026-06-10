# ADR 0005: Isar schema versioning and migration safety

**Status:** Accepted (persistence engine amended by ADR 0007; corrupt-open
recovery amended 2026-06-10)
**Date:** 2026-05-28

> **Amendment (ADR 0007, 2026-05-28):** the persistence engine moved from the
> unmaintained `isar` 3.1.0 to the `isar_community` 3.3.0 fork. The
> collection-name versioning strategy, the `SchemaMigrator` interface, the
> failure-mode UX, and the per-version fixtures described below are all
> unchanged; only the underlying package changed. See ADR 0007.

> **Amendment (2026-06-10): conservative corrupt-open recovery.** A reviewer
> found the original corrupt-DB recovery (`IsarSetup.openForApp`) too
> aggressive: it DELETED the whole DB directory on ANY open failure. That
> destroys data on recoverable causes (a full disk, where freeing storage was
> the real fix; a 32-bit `armeabi-v7a` mmap-placement failure), and it
> contradicts this ADR's "the decision is the parent's, never the app's" for
> `RawEventLogV1`, which this ADR itself treats as the recovery source of truth,
> not merely "reconstructible". This is the explicit, recorded reversal of that
> delete-on-failure behavior. The open now: (1) passes an explicit
> `maxSizeMiB` (128) so the default 512 MiB mapping does not itself fail to
> place in a 32-bit process; (2) retries ONCE (clearing any half-registered
> instance) so a transient lock does not trigger recovery at all; (3) only then
> QUARANTINES the directory by renaming it aside to `lighthouse_db_corrupt/`
> (backup-excluded exactly like the live DB, tied in `backup_exclusion_test`) so
> the child's tap history is preserved for inspection or hand-recovery rather
> than destroyed; and (4) sets `CrashCapture.banditStateCorruptionFlag` (the
> diagnostic designed for this event, which was previously never set anywhere).
> A fresh DB is then opened so the board returns; only glow learning resets,
> which is genuinely reconstructible. The app still never blocks the child's
> board on a corrupt DB; it just no longer destroys recoverable data to do so.

## Context

The bandit's learned state (per-child Knowledge Base of (state, button) →
(α, β)) is persisted to Isar. Over time, the schema will change:

- Adding a new context dimension (e.g., promoting `Location` from
  `WifiHash`-derived to a first-class context field)
- Renaming a field
- Migrating from a flat (state, button) → params map to a more efficient
  data structure
- Refactoring the context-key string format

Each of these is benign engineering. But the cost of a botched migration is
not benign: it silently destroys a child's weeks of communication learning.
For a non-speaking child, that's not "data loss", that's regressing their
mode of expression.

This decision must be locked in from day one because the strategy chosen
constrains the schema definitions of all future versions.

## Decision

### Collection-name versioning, not per-row schemaVersion

Each schema version owns its own Isar collection, named with an explicit
suffix. The MVP collection is `BanditStateV1` (and any siblings such as
`KnowledgeBaseV1`, `RawEventLogV1`). A future revision creates
`BanditStateV2` alongside the V1 collection rather than mutating V1.

Rejected alternative: per-row `schemaVersion: int` field with branching
deserialization. That pattern accumulates branching code over time,
co-locates V1 and V2 logic in the same class, and makes "is this device on
V1 or V2?" a per-row question rather than a per-collection question. The
collection-name approach is safer for the "never silently destroy learned
state" requirement.

### Explicit `SchemaMigrator` interface

```dart
abstract class SchemaMigrator {
  int get fromVersion;
  int get toVersion;
  Future<MigrationResult> migrate(Isar isar);
}

sealed class MigrationResult {
  const MigrationResult();
}

class MigrationSuccess extends MigrationResult { ... }
class MigrationFailure extends MigrationResult {
  final String reason;
  final Map<String, dynamic> diagnostics;
  ...
}
```

Each schema bump ships a corresponding migrator: `V1ToV2Migrator`,
`V2ToV3Migrator`, and so on. App startup runs the chain in order, idempotently.

### Migration failure must not silently wipe state

If any migrator returns `MigrationFailure`, the app does not start into the
normal flow. Instead it surfaces a modal to the parent:

> Your child's learned patterns from a previous version couldn't be
> upgraded. Tap "Keep old data" (read-only) or "Start fresh" (resets
> learning).

- "Keep old data" mounts the previous version's collection read-only and
  disables further learning. The bandit operates on the frozen state until
  the parent chooses to start fresh.
- "Start fresh" archives the failed-to-migrate collection (renamed to
  `BanditStateV1_archived_<timestamp>`) and creates an empty V2 collection.
  The archive is kept locally; it is never auto-deleted.

The decision is the parent's, never the app's. A failed migration is a
surfaced event, not a silent reset.

### Test fixtures per version

Each schema version ships with three frozen fixture files in
`test/fixtures/`:

| Fixture | Purpose |
|---|---|
| `bandit_state_vN_happy.json` | Clean N → N+1 migration path |
| `bandit_state_vN_corrupted.json` | Partial / malformed state; exercises the user-prompt failure path |
| `bandit_state_vN_max_scale.json` | 5,000 unique context keys; tests cardinality leak scenarios and migration performance |

CI runs the full migration chain end-to-end against all prior fixtures on
every release. A migrator that cannot handle the corrupted fixture without
data loss does not ship.

### Naming and discoverability

- Collections: `BanditStateV1`, `BanditStateV2`, ... (no aliases, no
  un-versioned names)
- Migrators: `V1ToV2Migrator`, `V2ToV3Migrator`, ...
- Tests: `test/migrations/v1_to_v2_test.dart`, etc.
- Fixtures: `test/fixtures/bandit_state_v{N}_*.json`

## Consequences

- The codebase will accumulate one collection class per schema version. We
  do not delete old version classes lightly; they are needed for the
  "Keep old data" read-only path. Pruning V1 only happens once we have
  confidence that no installed app version is still on V1, which in practice
  means after enough release cadence has passed.
- The `BanditStateV1` collection name appears in tens of files. Renaming
  it is a breaking change requiring a migrator.
- New contributors will see multiple "current" collection classes and need
  to understand which is the active write target. A `lib/persistence/active.dart`
  file exports the active version constant to keep this discoverable.
- The migration code is the highest-risk code in the codebase by impact
  (its failure mode is silent destruction of a non-speaking child's weeks
  of communication learning). It gets the strictest review and the most
  test coverage.

## Alternatives considered

- **Per-row `schemaVersion` field with branching deserialization.** Rejected,
  see above.
- **Drop and recreate on schema change.** Rejected. Trivial to implement,
  catastrophic on alpha update day. Off the table.
- **Delegate to a versioning library (e.g., Drift's schema versioning).**
  Considered. Rejected because we are committed to Isar and rolling our
  own gives full control of the failure-mode UX, which is the most
  important property.

## Reviewers

- Engineering review: proposed 2026-05-28
- Independent reviewer: flagged the absence of
  schema versioning in initial design, prompting this ADR 2026-05-28
- Independent reviewer (second pass): added requirements for
  corrupted-state and max-scale fixtures 2026-05-28
- Clinical lead (BCBA): N/A (engineering decision); the
  user-facing failure-mode copy will be reviewed when implemented
