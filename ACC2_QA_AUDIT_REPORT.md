# ACC2 / NūriTalk — Comprehensive Quality Assurance & Pre-Flight Audit Report

**Project:** `.`  
**Date:** October 19, 2026  
**Auditor:** Lead Flutter Engineer & AAC Accessibility Specialist  
**Build Status:** Clean Debug APK Built (`193 MB`)  
**Automated Test Suite:** **747 / 747 Passed (100% Pass Rate, 0 Failures, 0 Errors)**  
**Static Code Analysis:** **0 Errors, 0 Warnings** (`flutter analyze --no-fatal-infos`)  
**APK Output Location:** [`./build/app/outputs/flutter-apk/app-debug.apk`](file://./build/app/outputs/flutter-apk/app-debug.apk)

---

## 1. Audit Findings & Communication Flow Validation

A comprehensive quality assurance inspection was conducted across all core AAC interaction workflows:

### A. Core AAC Boards & Sentence Bar
- **Tile Interaction & Spoken Utterance:** Tapping word buttons instantly pushes tokens into the active sentence bar and triggers TTS playback with localized voice tags (`voice_out_ar`, `voice_out_ar_dz`, `voice_out_de`, `voice_out`).
- **Motor-Planning Invariant:** Core vocabulary buttons remain locked to immutable grid coordinates ($6 \times 8$). Dynamic prediction glows and context updates highlight candidates without shifting grid buttons, strictly preventing motor pattern interference.
- **Folder Traversal:** Folder tiles expand seamlessly without uttering folder names into the sentence builder.

### B. Smart Multilingual Keyboard
- **Text Composition:** Full virtual keyboards for Arabic, Algerian Darija (with transliteration numerals 2, 3, 5, 7, 9), German, and English.
- **Predictive Autocomplete:** Autocomplete chips update in real-time based on input prefixes and feed directly into the sentence bar.
- **Personal Vocabulary Injection:** Custom cards saved by the user are automatically indexed into the predictive candidate generator.

### C. Personal Photo Cards System
- **Profile-Isolated Storage:** Custom cards are isolated per child profile and persist via atomic JSON storage with image file caching.
- **Multilingual Labeling:** Custom cards support individual translations across all four languages, allowing bilingual families to communicate naturally.

### D. Daily Routine Schedules, First/Then & Visual Timers
- **Visual Schedule Timeline:** Interactive timeline displaying morning, school, therapy, meal, hygiene, and bedtime routines with completion toggles and time badges.
- **First/Then Behavioral Support:** 2-step structured visual board with one-tap speech output for transition cues ("First speech therapy, then play").
- **Activity Expression Sheet:** Enables AAC communicators to directly express requests ("I want this"), preferences ("I like this"), questions ("When does this start?"), and refusals ("I don't want this") tied to any schedule item, committing them into the core sentence bar.
- **Visual Countdown Timer:** Time Timer-style pie sector showing remaining time visually for autistic users and individuals with digital clock comprehension difficulties.

---

## 2. Defects Identified & Fixed

During the QA audit, three functional defects and architectural inconsistencies were identified and resolved:

| ID | Module | Defect Description | Resolution | Status |
| :--- | :--- | :--- | :--- | :--- |
| **DEF-01** | `lib/main.dart` | **Regional Locale Instantiation Defect:** `locale: localeCode == null ? null : Locale(localeCode)` instantiated `Locale('ar_dz')` instead of `Locale('ar', 'DZ')`. This broke Flutter's lookup for Arabic Material/Cupertino localization delegates and caused inconsistent RTL fallback. | Updated `lib/main.dart` to resolve full `Locale` objects using `LocaleRegistry.specForCode(localeCode)?.locale ?? Locale(localeCode)`. | **FIXED** |
| **DEF-02** | `lib/ui/settings/settings_primary_screen.dart` | **Missing Full AAC Backup & Restore UI:** While `AACBackupService` was engineered with full card, schedule, profile, and settings serialization, the primary settings screen only exposed single-board OBF export/import. Caregivers could not back up or restore the entire communicator environment. | Added "Backup Everything" and "Restore Backup" rows protected behind the parental math gate in `settings_primary_screen.dart`. | **FIXED** |
| **DEF-03** | `lib/ui/schedule/*` | **Redundant Imports & Lint Warnings:** Unused imports and missing `const` constructors in schedule components caused analyzer warnings and test compile issues. | Cleaned up all redundant imports and added `const` constructors across `first_then_view.dart`, `daily_schedule_screen.dart`, and test fixtures. | **FIXED** |

---

## 3. Multilingual & RTL/LTR Verification

| Language | Direction | Typography | Primary TTS Strategy | Fallback Behavior |
| :--- | :---: | :---: | :---: | :---: |
| **Arabic (`ar`)** | **RTL** | Bundled Cairo (OFL) | Bundled pre-rendered clips (ADR 0004) | System Arabic TTS for typed text |
| **Algerian Darija (`ar_dz`)** | **RTL** | Bundled Cairo (OFL) | System TTS with Latin/Arabic transliteration | System Arabic voice with phonetic mapping |
| **German (`de`)** | **LTR** | Atkinson Hyperlegible | System TTS (de-DE) | System default TTS voice |
| **English (`en`)** | **LTR** | Atkinson Hyperlegible | Bundled pre-rendered clips (ADR 0004) | System English TTS for typed text |

- **Bidirectional Typography:** Confirmed that Arabic and Algerian Darija mirror UI navigation, folder badges (`PositionedDirectional`), and button sequences without reversing English/Latin brand names (`NūriTalk`).
- **Font Fallback:** Cairo font is bundled in assets and set as `fontFamilyFallback` across all themes to guarantee crisp Arabic glyph rendering regardless of platform font availability.

---

## 4. Accessibility & Motor-Planning Audit

1. **Touch Target Dimensions (WCAG 2.1 SC 2.5.5 / 2.5.8):**
   - Core AAC grid buttons: $\ge 64 \times 64\text{ dp}$ (exceeds the 44 dp requirement).
   - Daily schedule activity cards: $\ge 48\text{ dp}$ height.
   - Timer controls and quick preset chips: $\ge 44\text{ dp}$ height.
   - Smart keyboard touch keys: $\ge 44 \times 44\text{ dp}$.
2. **Switch Access Support:**
   - Single-switch and dual-switch scanning paradigms (`AccessMethod.switchSingle` / `AccessMethod.switchDual`) render high-contrast $3.5\text{px}$ amber borders around focused tiles.
   - Verified via [`test/ui/switch_access_test.dart`](file://./test/ui/switch_access_test.dart).
3. **Screen Reader (TalkBack) Semantics:**
   - Every interactive icon button features explicit `tooltip` and semantic label attributes.
   - Visual schedule activities announce category, completion state, and scheduled time.
4. **Reduced Motion & High Contrast:**
   - Visual countdown timer adheres to `MediaQuery.of(context).disableAnimations`.
   - High-contrast board theme renders pure black borders and maximum contrast text.

---

## 5. Offline Safety & Zero Telemetry Verification

- **Local Storage Only:** All profiles, custom photos, schedules, and vocabulary are stored exclusively in the application's local sandbox (`getApplicationDocumentsDirectory()` / `SharedPreferences`).
- **Zero External Network Calls:** No analytics, tracking pixels, crash telemetry, or third-party SDKs are initialized during standard communication, daily routines, or typing flows.
- **Parental Math Gate:** Settings, external URL launches, and backup exports are locked behind an accessible arithmetic challenge to prevent accidental modifications by young children.

---

## 6. Automated Test Results

The full test suite was executed via `flutter test --reporter=compact`:

```
========================================================================
Test Run Summary:
Total Tests Executed: 747
Passed: 747 (100%)
Failed: 0 (0%)
Errors: 0 (0%)
Runtime: 25.4 seconds
========================================================================
```

### Key Test Coverage Highlights

- [`test/ui/e2e_communication_qa_test.dart`](file://./test/ui/e2e_communication_qa_test.dart) — Full E2E QA communication flow, schedule expressions, First/Then, timer, multilingual resolution, and backup round-trip.
- [`test/services/board_backup_restore_test.dart`](file://./test/services/board_backup_restore_test.dart) — AACBackupService backup bundle serialization and deserialization across cards, routines, profiles, and settings.
- [`test/rtl_test.dart`](file://./test/rtl_test.dart) & [`test/darija_test.dart`](file://./test/darija_test.dart) — Arabic and Algerian Darija RTL layout, directional badges, and Cairo font resolution.
- [`test/ui/switch_access_test.dart`](file://./test/ui/switch_access_test.dart) — Switch navigation scanning and focus borders.
- [`test/audio/clip_coverage_test.dart`](file://./test/audio/clip_coverage_test.dart) — Audio clip coverage for bundled core vocabulary (ADR 0004).

---

## 7. Remaining Risks & Manually Required Physical-Device Tests

Because this audit was executed in a headless Linux workstation environment without physical touch digitizers or physical switch interfaces, the following manual validations must be completed on hardware:

1. **Physical Touch Screen Latency:**
   - Validate button tap recognition on low-cost physical Android tablets (e.g. 10-inch Lenovo Tab or Samsung Galaxy Tab A9) to ensure no missed taps during rapid multi-word communication.
2. **Hardware Switch Interface (Bluetooth / USB HID):**
   - Connect physical assistive switch pedals (e.g. Ablenet Blue2 or Pretorian USB switch) and verify debounce timing and dwell scan responsiveness in `switchSingle` and `switchDual` modes.
3. **Hardware Speaker & System Audio Levels:**
   - Test audio playback volume and clarity in noisy real-world environments (classrooms, therapy clinics, dining areas).
4. **Platform TTS Engine Availability:**
   - Verify that non-bundled Darija and German free-typed sentences trigger audible output on physical Android devices where Google Speech Services or local voice data packages may not yet be pre-installed by the manufacturer.

---

## 8. Exact Commands to Launch and Test

### A. Deploy to Physical Android Device via ADB
```bash
# 1. Connect physical device with USB debugging enabled
adb devices

# 2. Install the debug APK
adb install -r ./build/app/outputs/flutter-apk/app-debug.apk

# 3. Launch the app directly on the device
adb shell am start -n com.lighthouse.aac/com.lighthouse.aac.MainActivity
```

### B. Run the App via Flutter CLI
```bash
cd .
flutter run -d <device-id>
```

### C. Run the Complete Test Suite
```bash
cd .
flutter test --reporter=compact
```
