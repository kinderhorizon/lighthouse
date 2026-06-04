# ADR 0002: No automatic telemetry; manual crash log sharing only

**Status:** Accepted
**Date:** 2026-05-28

## Context

Lighthouse AAC's brand promise is: "No data ever leaves the device." That claim
appears verbatim on the privacy screen, in the launch reel, in donor copy, and
in grant applications. The promise has to be true by architecture, not by
goodwill, because a single broken claim breaks trust permanently with a
population (special-needs parents) that is unusually sensitive to data practices.

We also need a way to debug crashes during alpha and into public beta. Standard
industry practice (Firebase Crashlytics, Sentry, Bugsnag) silently uploads
crash reports in the background. That conflicts with the absolute privacy claim.

Three options were on the table:
- (A) Absolute copy, no crash reporting in MVP
- (B) Honest copy ("no data leaves unless you opt in"), automatic opt-in
  reporting with off-by-default toggle
- (C) Defer all crash reporting to public beta

After review, a fourth option emerged that resolves the tension:
- (D) Manual share, not automatic reporting

## Decision

**Option (D).** The app captures crashes locally to device storage and never
transmits anything. The user (parent or clinician) initiates sharing
explicitly via a "Share crash logs" button in Settings, which opens the system
share sheet (`share_plus`). Default mailto target: `bugs@kinderhorizon.org`.

The privacy claim stays absolute ("No data ever leaves the device") because the
user, not the app, moves the file when they choose to share.

### Crash capture

- Wrap `runApp` in `runZonedGuarded`
- Register `FlutterError.onError` for sync framework errors
- Register `PlatformDispatcher.instance.onError` for async and platform-channel
  errors

### Crash log storage

- Location: `getApplicationCacheDirectory()/crash_logs/` (matches the implementation and the rationale below; crash logs are cache-tier, deliberately NOT under the backed-up support dir)
- Format: structured JSON, one file per crash
- Rolling buffer: last 20 crashes, older entries auto-pruned
- Total size cap: 10 MB hard ceiling, oldest pruned first when exceeded

### Backup exclusion (Phase 1 HARD REQUIREMENT)

The privacy claim is "no data ever leaves the device." Both iOS and Android
operating systems will silently copy app-support files to cloud backup
services (iCloud, Google One) by default. A crash logger that satisfies the
whitelist above but leaks the file via OS backup violates the claim by
channel even though the contents are communication-content-free.

The crash logger MUST therefore:

**iOS:**
- Store crash logs under `getApplicationCacheDirectory()` (Apple convention:
  cache dir is excluded from iCloud Backup), OR set the
  `com.apple.MobileBackup` extended attribute to `1` on the crash log
  directory at creation, OR both (belt and suspenders preferred).
- Verified at install time by reading the xattr back and logging a warning
  if it does not stick. A failed exclusion does not crash the app, but it
  does suppress further crash log writes until the exclusion is in place,
  to avoid silently breaching the privacy claim.

**Android:**
- Do NOT set `android:allowBackup="false"` (too blunt; kills all user data
  backup including legitimate user settings the parent expects to survive
  device migration).
- Declare an explicit `<exclude>` rule for the crash log path in:
  - `res/xml/data_extraction_rules.xml` (Android 12+, `cloud-backup` and
    `device-transfer` domains)
  - `res/xml/full_backup_content.xml` (older Android backup framework)
- Both files referenced from the `<application>` tag in
  `AndroidManifest.xml`.

The exclusion configuration is part of ADR 0002, not an implementation
detail. Future contributors must not remove or relax these rules without
amending this ADR.

### Isar database backup exclusion (privacy-critical)

Crash logs are communication-content-free by the whitelist below, but the
**Isar database is not**: `RawEventLogV1` records the child's button taps,
which are communication content, and `BanditStateV1` is derived from them. The
database therefore must never leave the device under any channel.

The DB opens under `getApplicationSupportDirectory()`, which on Android maps to
`getFilesDir()`, a directory Android Auto Backup and device-transfer **include
by default**. A backup configuration that excludes only `crash_logs/` (which
lives in the cache dir and is never backed up anyway) leaves the DB exposed.

Therefore the DB is isolated in a dedicated subdirectory,
`getApplicationSupportDirectory()/lighthouse_db` (`IsarSetup.dbSubdir`), and the
whole subdir is excluded (`<exclude domain="file" path="lighthouse_db/" />`) in
both `data_extraction_rules.xml` (cloud-backup and device-transfer) and
`full_backup_content.xml`. Excluding the directory rather than Isar's internal
filenames keeps the rule stable. `test/privacy/backup_exclusion_test.dart` ties
the XML path to `IsarSetup.dbSubdir` so the code and rules cannot drift, and
fails CI if the exclusion is dropped or a `domain="database"` rule re-enters.

iOS has the SAME exposure, and it is NOT automatic: `getApplicationSupportDirectory()`
maps to `Library/Application Support`, which iCloud Backup and device transfer
include by default (only `Library/Caches` and `tmp` are excluded). iOS has no
per-path backup XML, so the directory is marked with the
`NSURLIsExcludedFromBackupKey` resource value in `AppDelegate.swift` at launch
(before the Dart entrypoint opens Isar), which excludes the directory and its
contents from backup. The subdir name there must match `IsarSetup.dbSubdir`.

### Crash log whitelist (allowed fields)

- `timestamp` (UTC ISO-8601)
- `app_version`
- `build_number`
- `os` (e.g., "iOS 18.2", "Android 14")
- `device_model` (e.g., "iPad Air 11-inch (M2)", "SM-X716")
- `locale` (e.g., "en_CA", "ar_SA")
- `stack_trace`
- `exception_type`
- `exception_message`
- `last_ui_route` (e.g., "/grid/core_main")
- `isar_db_size_bytes`
- `unique_context_keys_count`
- `bandit_state_corruption_flag` (boolean)

### Explicitly excluded from crash logs

- Button taps, button labels, voice-out content, board contents
- WiFi SSID, WiFi hash, location data
- Anything derived from communication content
- Anything the parent or child typed or selected

The exclusion list is enforced as a positive whitelist in code: the crash
logger constructs the JSON payload by reading exactly the fields in the list
above. There is no "log additional context" path.

### Share UX

- Settings → Clinician/Advanced menu (math-gated, see ADR 0003 § Settings) →
  "Share crash logs"
- Tapping opens `share_plus` system share sheet with the JSON file
- Default email target: `bugs@kinderhorizon.org`
- "View crash logs" button lets the user preview the JSON file before sharing,
  so the privacy claim is verifiable, not just trusted

### Mailto target rationale

Only `bugs@kinderhorizon.org` is baked into the binary. `support@` and `help@`
are reserved for future website/marketing surfaces and intentionally NOT
referenced in app code, to preserve routing flexibility post-launch without
requiring an app update.

## Consequences

- The absolute privacy claim is enforced by design, not policy. Future
  contributors cannot accidentally introduce a network call to a telemetry
  endpoint, because there is no telemetry SDK in the dependency tree.
- No `firebase_crashlytics`, `sentry_flutter`, `bugsnag`, or equivalent in
  `pubspec.yaml`. Adding any of these requires a new ADR explicitly retiring
  this one.
- Alpha debugging signal is limited to what families voluntarily share.
  Acceptable trade-off for the 3-5 family alpha; revisit if public beta scale
  forces it.
- Future contributors will be tempted to "improve" this with automatic
  opt-in reporting (Sentry-with-toggle, etc.). The temptation is structural,
  not philosophical: every Flutter engineer's habit is "add Crashlytics on day
  one." This ADR is the gate. Re-opening requires a new ADR with explicit
  brand-voice consideration, not a PR with a checkbox.

## Alternatives considered

- **(A) No crash reporting at all.** Considered, but loses too much debugging
  signal. (D) gives us the same privacy property at near-zero engineering cost.
- **(B) Automatic opt-in reporting with off-by-default toggle.** Considered.
  Rejected because the privacy claim then has to be qualified ("no data leaves
  unless you opt in"), which dilutes the strongest marketing claim before the
  product even ships. The "automatic but opt-in" pattern is also famously
  poorly understood by users; many believe they are opted in when they are not,
  and vice versa.
- **(C) Defer to public beta.** Considered. Rejected because (D) is cheaper to
  ship now than to retrofit later, and we want the manual-share path battle-
  tested during alpha.

## Reviewers

- Engineering review: proposed 2026-05-28
- Independent reviewer: reviewed 2026-05-28
- Independent reviewer (additional pass): reviewed
  2026-05-28 with additions for `isar_db_size_bytes` and
  `unique_context_keys_count` whitelist fields
- Independent reviewer (toolchain advisory):
  2026-05-28 with the iOS/Android backup exclusion section, addressing a
  channel-not-content leak vector for the privacy claim
- Clinical lead (BCBA): N/A (architectural decision)
