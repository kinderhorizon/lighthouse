# Lighthouse AAC: app data inventory

Single source of truth for the hosted privacy policy (`/lighthouse/privacy`)
AND the App Store "App Privacy" / Google Play "Data Safety" forms. Every entry
is read from the code and cites its source so a reviewer can verify the claim
against the implementation. If the code changes, this file changes first.

Authored 2026-05-31 (claim-vs-code pass). App is open source (MIT), so every
line here is independently checkable.

Conventions used below:
- "App Support" = the platform application-support directory
  (`getApplicationSupportDirectory()`); excluded from OS cloud backup (see
  section D).
- "Cache" = the platform cache directory (`getApplicationCacheDirectory()`);
  excluded from OS cloud backup by default on both platforms, and transient.
- "Prefs" = `SharedPreferences` (Android) / `NSUserDefaults` (iOS); part of the
  standard OS backup. Holds app settings only, no child content.

---

## A. On-device only. Never transmitted.

Nothing in this section ever leaves the device by any code path. There is no
account, no login, no analytics SDK, no automatic crash reporting, and no
server the app contacts on its own.

| Data | What it is | Where stored | Leaves device? | Source |
|---|---|---|---|---|
| Learned word weights (bandit posteriors) | Per-button `alpha`, `beta`, `observationCount`, `updatedAt`, keyed by `buttonId` / `stateKey`. The model that surfaces a child's most-used words. | Isar DB, App Support, subdir `lighthouse_db` | No | `lib/persistence/bandit_state_v1.dart`; `lib/persistence/isar_setup.dart` (`dbSubdir = 'lighthouse_db'`) |
| Raw tap / event log | One row per interaction: `timestamp`, `eventType`, `buttonId`, `boardId`, `stateKey`. The child's communication activity. | Isar DB, App Support, subdir `lighthouse_db` | No | `lib/persistence/raw_event_log_v1.dart`; `isar_setup.dart` |
| Custom buttons | Parent-authored buttons (label, voice-out, etc.). | App Support, `custom_buttons.json` | No (except via deliberate board share, section B, which strips photos) | `lib/services/custom/custom_button_store.dart` (`fileName = 'custom_buttons.json'`) |
| Custom button images | Photos a parent attaches to a custom button. May include a photo of the child. | App Support, `custom_images/` | No. Board share (section B) strips these. | `custom_button_store.dart` (`imagesSubdir = 'custom_images'`) |
| Home favourites | The favourites strip selection. | App Support, `home_favourites.json` | No | `lib/services/favourites/favourites_store.dart` (`fileName = 'home_favourites.json'`) |
| Board layout overrides | Parent repositioning of tiles. | App Support, `board_layout.json` | No | `lib/services/layout/board_layout_store.dart` (`fileName = 'board_layout.json'`) |
| Hidden tiles | Which tiles a parent has hidden from a board. | App Support, `hidden_tiles.json` | No | `lib/services/layout/hidden_tiles_store.dart` (`fileName = 'hidden_tiles.json'`) |
| Icon overrides | Parent-chosen replacement pictograms for tiles, and their image files. | App Support, `icon_overrides.json` + `icon_overrides/` | No | `lib/services/layout/icon_override_store.dart` (`fileName = 'icon_overrides.json'`, `imagesSubdir = 'icon_overrides'`) |
| Custom voice recordings | Parent-recorded audio clips mapped to tiles (the parent's or child's voice). | App Support, `custom_voices.json` + `custom_voices/` | No. Board share (section B2) carries voice-out TEXT only, never the audio clips. | `lib/services/voice/custom_voice_store.dart` (`fileName = 'custom_voices.json'`, `clipsSubdir = 'custom_voices'`) |
| Imported boards | Vocabulary boards received from another family and imported. | App Support, `imported_boards/` | No | `lib/services/board_registry.dart` (`importSubdirName = 'imported_boards'`) |
| OTA content overlay | Corrected words / pictures / sounds applied via "Check for updates" (active; the fetch is section B3). | App Support, `content_overlay/` | No (inbound only) | `lib/services/ota/content_overlay_store.dart` (`subdirName = 'content_overlay'`) |
| App settings | TTS mode, glow style, hitbox magnitude, locale override, auto-return, hide-tile-text. | Prefs | No (synced to the user's own OS backup only, see D) | `lib/services/settings/settings_repository.dart` |
| Onboarding answer | `onboarding.completed` flag + `onboarding.home_label` (Home/School/Both/Other). | Prefs | No (OS backup only) | `lib/services/onboarding/onboarding_repository.dart` |

Note: a child's photos (custom button images) are App-Support-stored and never
transmitted; the one share path that touches a photo button (section B) clears
the image reference before sharing.

---

## B. Voluntary, parent-initiated egress that EXISTS TODAY.

Two things, both requiring a deliberate parent action. The app sends nothing
automatically and contacts no KHF server for either: a crash report goes out
through the device's native mail composer (pre-addressed to KHF, with an OS
share-sheet fallback), and a shared board goes out through the OS share sheet.
The parent taps send / picks the destination in their own apps.

### B1. Sending a crash report

- **Trigger:** Settings > Crash logs > "Send crash logs". A separate "View
  crash logs" screen lets the parent read the exact stored contents first;
  viewing is available but is NOT forced before sending. (Policy copy should
  say the contents are *viewable*, not that a preview is *required*.)
- **Mechanism:** the device's native mail composer (`flutter_email_sender`),
  pre-addressed to `bugs@kinderhorizon.org` with the crash-log file(s)
  attached. The parent must tap send in their own mail app; nothing is sent in
  the background, no KHF server is contacted, and no HTTP client is used,
  transmission rides the parent's own mail account. If no mail account is
  configured (common on iOS), it falls back to the OS share sheet
  (`share_plus`), where the parent picks the destination; the suggested body
  text names `bugs@kinderhorizon.org`. Either path is parent-initiated and
  server-less.
- **Stored at:** Cache, `crash_logs/*.json` (transient; OS-backup-excluded).
- **Source:** `lib/services/crash/crash_log_store.dart`
  (`getApplicationCacheDirectory()`, `subdirName = 'crash_logs'`);
  `lib/services/crash/crash_log.dart`; send action in
  `lib/ui/settings/settings_primary_screen.dart` (`_sendCrashLogs`, with
  `_shareCrashLogsViaSheet` fallback).
- **Exact fields in a crash report** (`crash_log.dart`), all of which travel
  when shared. The earlier policy draft listed only model / OS / error
  type+message+trace; the real set is larger and the policy must match it:
  - `timestamp`
  - `appVersion`, `buildNumber`
  - `os` (operating-system version string)
  - `deviceModel`
  - `locale`
  - `exceptionType`, `exceptionMessage`, `stackTrace` (FREE TEXT produced by
    the failure; the app does not author these and does not log the child's
    tapped words into them, but because they are free text the parent should
    view before sharing)
  - `lastUiRoute` (optional; the screen route active at the crash, e.g. a
    board or settings route, not communication content)
  - `isarDbSizeBytes` (optional; a size number)
  - `uniqueContextKeysCount` (optional; a diagnostic count, not content)
  - `banditStateCorruptionFlag` (optional bool)
- **Data Safety mapping:** "App activity" / "Crash logs" + "Diagnostics",
  user-initiated, not linked to identity, not for tracking. (Matches the
  locked store-form decision.)

### B2. Sharing a vocabulary board

- **Trigger:** the board editor's share action.
- **Mechanism:** OS share sheet; a single `.json` file is written to a temp
  dir, shared, then deleted in a `finally` block.
- **What travels:** vocabulary STRUCTURE only, exactly `AACBoard.toJson()`. The
  child's learned usage cannot travel: the bandit posteriors and the raw tap
  log are separate Isar collections the board model holds no reference to.
  `base_weight` is a static authoring prior (only writer is
  `AACButton.fromJson`), not learned usage. Custom photos are stripped
  (`icon_uri` cleared) and folder buttons dropped. The pack is a single JSON
  file with no byte-embedding, so a nulled `icon_uri` ships no photo bytes.
- **Source:** `lib/services/board_pack_exporter.dart`; share/cleanup in
  `lib/ui/edit/board_edit_screen.dart`. Enforced by the key-set contract test
  `test/services/board_pack_exporter_test.dart` (any new `toJson` field fails
  CI).
- **Data Safety mapping:** the shared file is parent-authored vocabulary, sent
  device-to-device by the parent's choice, not collected by KHF.

### B3. Checking for content updates (OTA)

- **Trigger:** the parent taps "Check for updates" in Settings. Never
  automatic, never on launch, never in the background.
- **What travels (request):** ONLY the app's marketing version string (e.g.
  `0.1.0`), in the `X-Lighthouse-App-Version` header, over HTTPS. No device id,
  no build number, no usage, no child data. The build number is compared
  locally and is never sent (ADR 0021). The response is a signed content
  manifest plus the corrected files: inbound only.
- **Endpoint:** `OTA_BASE_URL` in `config/release.json`, LIVE in the alpha (the
  KHF Azure Blob content host). A release build that omits it fails the
  compile-time release guard, so this is active, not dormant.
- **Source:** `lib/services/ota/ota_config.dart`,
  `lib/services/ota/content_http_client.dart`,
  `lib/services/ota/content_update_service.dart`. See ADR 0017 / ADR 0021.
- **Data Safety mapping:** the only outbound payload is an app-version string;
  the content is an inbound fetch. No personal data collected.

### B4. Sending feedback

- **Trigger:** the parent taps Send on the feedback screen. Never automatic.
- **What travels:** the parent's typed message, an OPTIONAL contact email if
  provided, and `appVersion` / `osVersion` / `locale`, over HTTPS. No device
  fingerprint beyond app/OS version. Carries nothing about the child or their
  boards. The message + email are the PARENT's data.
- **Relay:** an Azure Function (Canada region) that forwards to a KHF email
  inbox and stores nothing at rest (no database, no payload in logs).
- **Endpoint:** `FEEDBACK_URL` in `config/release.json`, LIVE in the alpha. The
  client returns `notConfigured` only when the URL is empty (non-release
  builds); release builds bake it in via the guard, so this is active.
- **Source:** `lib/services/feedback/feedback_submission.dart`,
  `feedback_client.dart`, `feedback_config.dart`; relay in `cloud/feedback/`.
- **Data Safety mapping:** parent-provided message + optional email + app/OS/
  locale, sent by the parent's action, not collected automatically.

---

## C. (Previously dormant) OTA + feedback are now ACTIVE.

Earlier builds gated OTA and in-app feedback off behind an empty compile-time
endpoint. As of the alpha, `config/release.json` ships live `OTA_BASE_URL` and
`FEEDBACK_URL` and the compile-time release guard REQUIRES them, so both are
active in shipped builds. Their live wire payloads are documented above as
sections B3 (OTA) and B4 (feedback). Nothing in the app is dormant now.

---

## D. Backup posture (how the above maps to OS cloud backup)

The privacy claim is "only basic app settings are part of your device's
standard backup; everything your child creates is excluded." Verified:

- **Excluded from backup:** all parent/child-authored content, because it all
  lives under App Support, and:
  - iOS excludes the WHOLE Application Support directory from backup
    (`AppDelegate.swift`, `excludeApplicationSupportFromBackup` setting
    `NSURLIsExcludedFromBackupKey`).
  - Android lists each path in `data_extraction_rules.xml` +
    `full_backup_content.xml`, bound to the code constants by
    `test/privacy/backup_exclusion_test.dart`.
- **Crash logs** live in Cache, which both platforms exclude from cloud backup
  by default (iOS `Library/Caches`; Android `getCacheDir()` is auto-excluded),
  and are transient.
- **Backed up (intentionally):** only Prefs (app settings + the onboarding
  flag/label). No child communication content is in Prefs.
- **Residual check (was flagged open):** no store writes child/custom content
  outside the excluded set. Confirmed: every durable store resolves its base
  via `getApplicationSupportDirectory()` (Isar, custom buttons + images,
  favourites, layout, hidden tiles, icon overrides + images, custom voice
  recordings + clips, imported boards, OTA overlay); crash logs use Cache; the
  board-share temp file is deleted after share. Nothing child-authored lands in
  Prefs or any backed-up location.

---

## E. Notes for the policy / store-form authors

1. **Crash report field list:** use the full set in B1, not the shorter draft
   list. Under-describing a Data Safety disclosure is a policy risk.
2. **Preview wording:** crash-log contents are *viewable* before sharing, not
   force-previewed. Do not claim a mandatory preview step.
3. **Region:** the feedback relay runs in Azure Canada; drop any US-region /
   Data Privacy Framework / SCC language (see the privacy-delta decision).
4. **Activation:** OTA + in-app feedback are ACTIVE in the alpha (sections B3 /
   B4); the published policy and store forms must describe them as live data
   flows, not future features.
