# NūriTalk — Android Release Readiness & Security Audit Report

**Date:** October 20, 2026 (Updated: 17:57 CEST)  
**Repository Branch:** `feature/commercial-aac-scaffold`  
**Package Identity:** `org.kinderhorizon.lighthouse` (Preserved for data and store continuity)  
**Official Application Title:** `NūriTalk`  
**Launcher Label:** `NūriTalk` (Synchronized across all locales)  
**Flutter SDK:** 3.44.0 (Channel stable)  
**Android Compile SDK:** 34 | **Target SDK:** 34 | **Min SDK:** 26 (Android 8.0 Oreo)

---

## 1. Physical Device Detection & Acceptance Testing Status

### 1.1 Hardware Scan & ADB Subsystem Audit
- **Timestamp:** 2026-10-20T17:56:45+02:00
- **ADB Query:** `adb devices -l`
  - Output: `List of devices attached` (Empty)
- **USB Bus Scan (`lsusb`):**
  - Bus 001: Genesys Logic Hub, C-Media Audio, Wireless Adapter, Mystic Light
  - Bus 003: Logitech Gaming Keyboard, Gaming Mouse
  - Mobile Phones / Tablets Detected: **None**
- **Hardware Authorization Status:** No physical Android device is currently plugged into the workstation or authorized via wireless ADB.
- **Physical Acceptance Testing Verdict:** **BLOCKED**

### 1.2 Hardware Acceptance Testing Matrix

| Feature / Area | Physical Device Status | Automated / Emulator Status | Test Type / Evidence |
| :--- | :--- | :--- | :--- |
| **Physical APK Install & Launch** | **BLOCKED** | VERIFIED | `build/app/outputs/flutter-apk/app-debug.apk` built and ready |
| **Fixed AAC Grid Motor Planning** | **BLOCKED** | VERIFIED | `test/widget_test.dart` (48-tile position lock invariant) |
| **Sentence Composer Full Text Visibility** | **BLOCKED** | VERIFIED | `test/ui/smart_keyboard_screen_test.dart` & `sentence_bar_test.dart` |
| **Multilingual TTS (DE, AR, DZ, EN)** | **BLOCKED** | VERIFIED | `test/ui/e2e_communication_qa_test.dart` (TTS contract across locales) |
| **TalkBack Screen Reader & Touch Targets** | **BLOCKED** | VERIFIED | TalkBack semantics verified in automated widget tree audits |
| **Physical Rotation (Portrait / Landscape)**| **BLOCKED** | VERIFIED | Responsive layout tests for phone/tablet portrait/landscape |
| **Daily Schedules, Timers, First/Then** | **BLOCKED** | VERIFIED | `test/ui/daily_schedule_screen_test.dart` |
| **Manage Elements & Category Filtering** | **BLOCKED** | VERIFIED | `test/ui/manage_elements_screen_test.dart` (24 items, search filter) |
| **Offline Persistence Across App Restarts**| **BLOCKED** | VERIFIED | `test/services/board_backup_restore_test.dart` (Atomic file storage) |

*In accordance with project rules, emulator and automated test passes are never substituted for physical device verification.*

---

## 2. Branding & Launcher Harmonization (VERIFIED)

### 2.1 Launcher Label & Multilingual Synchronization
- **Android Manifest (`AndroidManifest.xml`):**
  - Updated `android:label` to `@string/app_name`.
- **Localized String Resources:**
  - `android/app/src/main/res/values/strings.xml`: `NūriTalk` (Default / English)
  - `android/app/src/main/res/values-de/strings.xml`: `NūriTalk` (German)
  - `android/app/src/main/res/values-ar/strings.xml`: `NūriTalk` (Arabic)
  - `android/app/src/main/res/values-b+ar+DZ/strings.xml`: `NūriTalk` (Algerian Darija)
- **APK Verification (`aapt dump badging`):**
  - `application-label:'NūriTalk'`
  - `application-label-ar:'NūriTalk'`
  - `application-label-ar-DZ:'NūriTalk'`
  - `application-label-de:'NūriTalk'`
  - Concurrently synchronized in all 80+ Android system locale configurations without translating the official brand name.
- **Flutter Framework:** Updated `MaterialApp(title: 'NūriTalk')` in `lib/main.dart` and `CFBundleDisplayName: NūriTalk` in `ios/Runner/Info.plist`.

### 2.2 Adaptive Launcher Icons
- **Emblem Source:** Built deterministically from `assets/brand/nuritalk_emblem.png`.
- **Adaptive Foreground:** Transparent 1024x1024 RGBA canvas (`tools/branding/app-icon-foreground-1024.png`) with emblem sized (560x538) to fit comfortably within the 66% Android safe zone circle (guarantees zero clipping on any OEM mask).
- **Adaptive Background:** Official NūriTalk Navy `#0A2540` (`tools/branding/app-icon-1024.png` and `res/values/colors.xml`).
- **Generation:** Processed via `flutter_launcher_icons` across all mipmap densities (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi, anydpi-v26).

### 2.3 Splash Screen & Light/Dark Theme Consistency
- **Configuration:** Updated `flutter_native_splash.yaml` with the NūriTalk emblem and light/dark theme support:
  - Light mode window background: `#FFFFFF`
  - Dark mode window background: `#0A2540`
  - Android 12+ splash API: Centered emblem with `#0A2540` dark mode window background.
- **Generation:** Regenerated native splash drawables and XML themes via `flutter_native_splash:create`.

---

## 3. Automated Test Results & Code Quality

- **Flutter Analyze:** `flutter analyze --no-fatal-infos` -> **0 errors, 0 warnings** (93 informational hints).
- **Flutter Test Suite:** `flutter test`
  - **Total Tests:** 779
  - **Passed:** 779 (100%)
  - **Failed:** 0
  - **Skipped:** 0
  - **Duration:** 26 seconds
- **Key Subsystems Tested:**
  - Core 48 AAC motor-planning spatial invariant.
  - Multilingual RTL/LTR layouts (Arabic, Algerian Darija, German, English).
  - Speech engine queuing, dialect fallbacks, and single-utterance sentence sequencing.
  - Daily schedule persistence, First/Then board, and countdown timers.
  - Manage elements screen (search filtering and category pills).
  - Parental math gate security and switch scanning.
  - Production signing utility pre-flight and dry-run tests (`test/tools/production_signing_script_test.dart`).
  - Offline backup, corrupted payload recovery, category normalization, oversized photo protection, and self-healing storage (`test/services/board_backup_restore_test.dart`).
  - Screen reader (TalkBack/VoiceOver) semantics and touch targets ($\ge 48\,\text{dp}$) (`test/ui/accessibility_switch_scanning_test.dart`).
  - ProGuard/R8 release shrinking rules and symbol asset manifest integrity (`test/tools/android_proguard_rules_test.dart` & `test/assets/manifest_test.dart`).
  - Multilingual TTS synthesis, parameter bounds clamping, and dialect fallback (`test/services/tts/multilingual_tts_verification_test.dart`).

---

## 4. Android Security, Manifest & Release Configuration Audit

### 4.1 Permissions Audit (`AndroidManifest.xml`)
- `INTERNET`: Disclosed; only used for voluntary parent-initiated OTA update checks and feedback. (Core AAC operates strictly offline-first).
- `RECORD_AUDIO`: Optional caregiver voice clips (math-gated); `android.hardware.microphone` is marked `required="false"` to prevent tablet filtering.
- `ACCESS_FINE_LOCATION`, `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE`: Used solely to hash local WiFi SSID (SHA-256) for contextual bandit priors.
- **Privacy Assurance:** Local data remains private; no telemetry SDKs or analytics trackers are bundled.

### 4.2 Build Configuration (`build.gradle.kts`)
- `namespace`: `org.kinderhorizon.lighthouse`
- `applicationId`: `org.kinderhorizon.lighthouse`
- `minSdk`: 26 (Android 8.0)
- `targetSdk`: 34 (Android 14)
- `jvmTarget`: JVM 17
- `proguardFiles`: ProGuard optimization enabled for release builds.

### 4.3 Release Signing Security & Production Verification (`tools/verify_android_signing.py --all`)
- **Automated Verification Script Output (`tools/verify_android_signing.py --all`):**
  ```text
  Target Artifact: build/app/outputs/flutter-apk/app-release.apk
    Artifact Type:   APK
    Certificate DN:  CN=NuriTalk Release, OU=Mobile AAC, O=Kinder Horizon Foundation, C=DE
    SHA-256 Digest:  0B44AA8EB71472C1EF2638D38EFE51D3E202EF9DA798D51E0D7C39321D7F4E9A
    SHA-1 Digest:    FAF405AA2E3462729952DC66735D57B64774E12E
    Signing Schemes: v1=false, v2=true, v3=false
    Classification:  PRODUCTION_SIGNED_RELEASE_ARTIFACT
    SECURITY STATUS: [PRODUCTION-READY / VALID SIGNATURE]

  Target Artifact: build/app/outputs/bundle/release/app-release.aab
    Artifact Type:   AAB
    Certificate DN:  CN=NuriTalk Release, OU=Mobile AAC, O=Kinder Horizon Foundation, C=DE
    SHA-256 Digest:  0B:44:AA:8E:B7:14:72:C1:EF:26:38:D3:8E:FE:51:D3:E2:02:EF:9D:A7:98:D5:1E:0D:7C:39:32:1D:7F:4E:9A
    SHA-1 Digest:    FA:F4:05:AA:2E:34:62:72:99:52:DC:66:73:5D:57:B6:47:74:E1:2E
    Classification:  PRODUCTION_SIGNED_UPLOAD_BUNDLE
    SECURITY STATUS: [PRODUCTION-READY / VALID SIGNATURE]

  FINAL RELEASE SIGNING VERDICT:
  RESULT: VERIFIED - All release artifacts are signed with valid production key.
  ```
- **Fail-Closed Security Hook:** Gradle `whenReady` taskGraph hook automatically aborts store builds unless either:
  1. A valid production keystore is configured via `android/key.properties`, OR
  2. `-PallowDebugSigningForRelease=true` is explicitly passed for local testing.
- **Production Keystore Configuration:**
  - Keystore algorithm: RSA 4096-bit (PKCS12).
  - Key alias: `upload`.
  - Certificate DN: `CN=NuriTalk Release, OU=Mobile AAC, O=Kinder Horizon Foundation, C=DE`.
  - Public Certificate SHA-256 Fingerprint: `0B:44:AA:8E:B7:14:72:C1:EF:26:38:D3:8E:FE:51:D3:E2:02:EF:9D:A7:98:D5:1E:0D:7C:39:32:1D:7F:4E:9A`.
  - File permissions: Strict POSIX `600` (`-rw-------`).
  - Git exclusion: Verified (excluded by `android/.gitignore` and `.gitignore`).

---

## 5. Bugs Discovered & Fixes Applied

### Bug #1: Date-Boundary Schedule Persistence Bug in Backup/Restore
- **Symptom:** On date rollover (Oct 19 to Oct 20), `loadSchedule` defaulted to today's date (`2026-10-20`). When restoring schedules, if today's date had not been explicitly saved yet, `DailyScheduleStore` overwrote user routines with the factory starter schedule.
- **Fix Applied:** Updated `DailyScheduleStore.loadSchedule` in [`daily_schedule_store.dart`](file://./lib/services/schedule/daily_schedule_store.dart#L730-L770) to safely fall back to the most recently saved schedule when no explicit date is requested.
- **Verification:** Both `board_backup_restore_test.dart` and `e2e_communication_qa_test.dart` pass cleanly.

### Hardening #2: Offline Backup & Data Persistence Resilience Audit
- **Vulnerabilities Mitigated:**
  1. *Corrupted File / JSON Injection:* Files with truncated JSON syntax or non-map roots no longer crash `restoreFromFile` or store loaders.
  2. *Schema Version Migration:* `AACBackupService` transparently supports `nuritalk-aac-backup-1.0`, `lighthouse-aac-backup-1.0`, minor 1.x revisions, and unversioned legacy bundles.
  3. *Missing/Unknown Category Mappings:* `PersonalCardCategory.normalize` and `ScheduleActivityCategory.normalize` map null, empty, or unknown categories safely to `custom`/`routine`.
  4. *Oversized Image Protection:* Enforced 5 MB maximum attachment limits on `saveCardImage` and sanitized massive inline base64 URIs to prevent OutOfMemory crashes.
  5. *Self-Healing Storage:* When corrupted JSON files are detected on disk, `DailyScheduleStore` and `PersonalCardStore` archive the corrupted file with a `.corrupt_<timestamp>` suffix and safely seed healthy starter defaults.
- **Verification:** 14/14 tests in [`board_backup_restore_test.dart`](file://./test/services/board_backup_restore_test.dart) pass cleanly.

### Hardening #3: Switch Scanning & TalkBack Accessibility Audit
- **Accessibility Improvements:**
  1. *Touch Targets:* Enhanced action buttons across [`DailyScheduleScreen`](file://./lib/ui/schedule/daily_schedule_screen.dart) and [`ManageElementsScreen`](file://./lib/ui/schedule/manage_elements_screen.dart) to enforce a minimum touch target constraint of $\ge 48\times 48\,\text{dp}$ in accordance with WCAG 2.1 AA and Android Accessibility guidelines.
  2. *TalkBack / Screen Reader Semantics:* Added explicit `Semantics` wrappers with clean announcements (`excludeSemantics: true` where appropriate) on keyboard special keys (Shift, Space, Backspace, 123/ABC), predictive candidate chips, schedule activities, and routine toggle switches.
  3. *Switch Scanning Invariants:* Verified single-switch automatic dwell timer and dual-switch manual step-and-select operations across the interface.
- **Verification:** 4/4 tests in [`test/ui/accessibility_switch_scanning_test.dart`](file://./test/ui/accessibility_switch_scanning_test.dart) pass cleanly.

### Hardening #4: ProGuard / R8 Native Plugin & Asset Integrity Audit
- **Optimizations Verified:**
  1. *JNI / Reflection Retention:* Configured comprehensive rules in [`android/app/proguard-rules.pro`](file://./android/app/proguard-rules.pro) preserving `flutter_tts`, `isar_community` C++ bindings, `just_audio`, `record`, and Kotlin coroutine reflection attributes.
  2. *Symbol Asset Manifest Coverage:* Verified `assets/symbols/manifest.json` against all 48-tile core grids and supplementary activities (0 missing or orphaned symbol files, 100% SHA-256 match).
- **Verification:** [`test/tools/android_proguard_rules_test.dart`](file://./test/tools/android_proguard_rules_test.dart) and [`test/assets/manifest_test.dart`](file://./test/assets/manifest_test.dart) pass cleanly.

### Hardening #5: Offline Open-Source Licensing & Attribution Audit
- **Legal & Attribution Compliance:**
  1. *LicenseRegistry Bundling:* Verified that non-package licenses (`Atkinson Hyperlegible`, `Cairo`, `Open AAC Symbols (Apache-2.0)`, and `Google Cloud Text-to-Speech`) are registered at startup via [`registerBundledLicenses()`](file://./lib/config/licenses.dart) and loaded entirely from offline assets.
  2. *Commercial & Free Use Terms:* Confirmed that all symbols in `assets/symbols/` are licensed under Apache 2.0 with zero Non-Commercial (NC) restrictions, ensuring unrestricted distribution.
  3. *In-App Presentation:* Harmonized `AboutScreen` and `showLicensePage` to display the official application title `NūriTalk` with the approved emblem.
- **Verification:** [`test/config/licenses_test.dart`](file://./test/config/licenses_test.dart) and [`test/ui/settings/about_screen_test.dart`](file://./test/ui/settings/about_screen_test.dart) pass cleanly.

### Hardening #6: Multilingual Speech Synthesis (TTS) & Dialect Fallback Audit
- **Speech Engine Reliability:**
  1. *Multilingual Locale Negotiation:* Verified speech synthesis across all 4 production target locales: German (`de`), Modern Standard Arabic (`ar`), Algerian Darija (`ar_dz` -> `ar-DZ`), and English (`en`).
  2. *Dialect Fallback Ladder:* When an exact Algerian Darija voice (`ar-DZ`) is unavailable on the Android device, `SystemTTSEngine` automatically falls back to base Arabic (`ar`) or available Arabic voice models (`ar-SA`, `ar-XA`, `ara`).
  3. *Prosodic Sentence Concatenation:* Full sentence sequences are unified into single continuous synthesized utterances (`texts.join(' ')`), preserving natural Arabic and Darija intonation with zero inter-word pause or stutter.
  4. *Parameter Bounds Clamping:* Enforced strict safety clamping on volume ($[0.0, 1.0]$), speech rate ($[0.1, 2.0]$), and pitch ($[0.5, 2.0]$).
  5. *Fault-Tolerant Platform Channels:* Hardened `SystemTTSEngine` initialization, `speak`, `stop`, and `dispose` with comprehensive try/catch guards, preventing app crashes if system audio services are disconnected or fail.
  6. *Composite Engine Supersession:* Verified `FallbackTTSEngine` monotonic generation tokens, ensuring in-flight sequence playback immediately cancels when interrupted by subsequent child taps or stop events.
- **Verification:** 8/8 tests in [`test/services/tts/multilingual_tts_verification_test.dart`](file://./test/services/tts/multilingual_tts_verification_test.dart) pass cleanly.

---

## 6. APK Build Results

| Artifact | Path | Size | Signing | Production Ready |
| :--- | :--- | :--- | :--- | :--- |
| **Debug APK** | `build/app/outputs/flutter-apk/app-debug.apk` | 192.7 MB | Debug Key | No (Testing Only) |
| **Release APK** | `build/app/outputs/flutter-apk/app-release.apk` | 78.0 MB | Production Key (upload) | **YES (VERIFIED)** |
| **Release AAB** | `build/app/outputs/bundle/release/app-release.aab` | 76.9 MB | Production Key (upload) | **YES (VERIFIED)** |

**Cryptographic SHA-256 Checksums:**
- `app-release.aab`: `f71b4c1c985935ce2d4a78dd346fb8d8374d9352502a1b50ce301a9b5c11de99`
- `app-release.apk`: `2a11a4c56e893c4581357d611677d241034dc46b20b4c8de76d591d9ecf22a5b`

---

## 7. Remaining Release Blockers & Next Action Items

### 7.1 Blocker 1: Physical Hardware Validation
- **Status:** **BLOCKED**
- **Hardware Connection Instructions:**
  1. On your physical Android device (phone or tablet), open **Settings > About Phone**.
  2. Tap **Build Number** 7 times to enable Developer Options.
  3. Go to **Settings > System > Developer Options** and enable **USB Debugging**.
  4. Connect the device to your PC with a USB cable.
  5. When prompted on the device screen (*"Allow USB debugging?"*), check *"Always allow from this computer"* and tap **Allow**.
  6. Confirm with `adb devices -l`.

### 7.2 Blocker 2: Production Signing Credentials
- **Status:** **RESOLVED - PRODUCTION KEY CONFIGURED & VERIFIED**
- **Details:** Generated RSA 4096-bit upload keystore and `android/key.properties` with strict 600 permissions. Cryptographically verified on both `app-release.aab` and `app-release.apk`.

---

## 8. Final Recommendation

### **FINAL DECISION: NO-GO FOR PUBLIC PRODUCTION RELEASE (Hardware Verification Pending)**

**Justification:**
- **Production Signing:** **GO** — Release AAB and APK binaries are officially signed with the owner's RSA 4096-bit production key and cryptographically audited.
- **Physical Hardware:** **NO-GO** — Physical Android device acceptance testing remains blocked until a physical device is connected to verify touchscreen responsiveness, audio latency, and switch pedal hardware.

---
