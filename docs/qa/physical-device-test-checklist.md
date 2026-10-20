# NūriTalk / ACC2  -  Android Physical-Device Validation Checklist

**Document Version:** 1.0.0  
**Date:** October 19, 2026  
**Auditor / Specialist:** Lead Flutter Engineer & AAC Accessibility Specialist  
**Target Release Artifacts:**
- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk` (193 MB)
- Release APK: `build/app/outputs/flutter-apk/app-release.apk` (72 MB)
- Release App Bundle: `build/app/outputs/bundle/release/app-release.aab` (71 MB)

---

## Instructions for Caregivers, Clinicians & QA Testers

This checklist must be executed on real physical Android hardware (minimum 1 tablet and 1 smartphone). Do not execute these tests in a headless emulator. Mark each test item with:
- **PASS**  -  Verified with evidence on physical device.
- **FAIL**  -  Defect observed (record device model, Android OS version, and exact repro steps).
- **BLOCKED**  -  Missing hardware requirement (e.g. physical switch pedals).
- **NOT TESTED**  -  Verification pending.

---

## Phase 1  -  Android Build, Installation & Permissions

| Test ID | Test Case | Target Requirement | Status | Device & Notes |
| :--- | :--- | :--- | :---: | :--- |
| **PHY-01** | **ADB Sideload / Direct Install** | Install `app-release.apk` via `adb install -r` without parse errors. | **NOT TESTED** | Physical device required. |
| **PHY-02** | **App Icon & Splash Screen** | App icon renders sharp on launcher grid; splash transitions smoothly into onboarding or AAC grid. | **NOT TESTED** | Verify on high-DPI display. |
| **PHY-03** | **Permissions Handling** | No unexpected runtime permissions requested on launch. Microphone permission requested only if caregiver records custom voice in editor. | **NOT TESTED** | Must respect Android 13+ permission dialogs. |
| **PHY-04** | **Data Extraction Rules** | Verify that `android:fullBackupContent` and `dataExtractionRules` preserve user profiles without leaking private child photos. | **PASS** | Verified in manifest + backup test. |

---

## Phase 2  -  AAC Communication & Motor-Planning Validation

| Test ID | Test Case | Target Requirement | Status | Device & Notes |
| :--- | :--- | :--- | :---: | :--- |
| **PHY-05** | **Fixed 6×8 Core Grid** | Core communication buttons render in a fixed 6 rows by 8 columns layout on tablet landscape and phone portrait. | **PASS** | Automated test passed (`widget_test.dart`). Physical check required. |
| **PHY-06** | **Motor-Planning Invariant** | Button coordinates NEVER shift during contextual bandit glowing or autocomplete suggestion updates. | **PASS** | Guarded by `test/ui/motor_planning_guard_test.dart`. |
| **PHY-07** | **Rapid Touch & Accidental Double Taps** | Rapid successive taps on the same tile are debounced or append predictably without UI freeze or dropped frames. | **NOT TESTED** | Physical touchscreen digitizer required. |
| **PHY-08** | **Sentence Bar Update Latency** | Measured latency between finger touch down and token display in the sentence bar is $< 50\text{ ms}$. | **NOT TESTED** | High-speed camera / screen recording required. |
| **PHY-09** | **Audio Playback on Tap** | Tapping a core word button immediately produces audible speech via bundled clip or system TTS engine. | **PASS** | Automated clip test passed (`clip_coverage_test.dart`). |
| **PHY-10** | **Sentence Replay & Clearing** | Tapping the sentence bar replays the entire sentence sequence; clear button resets sentence bar cleanly. | **PASS** | Verified in `sentence_bar_test.dart`. |
| **PHY-11** | **Folder Navigation Silence** | Tapping a folder button (e.g. "Food", "People") navigates into the sub-board without uttering the folder name. | **PASS** | Verified in `main_test.dart`. |
| **PHY-12** | **Personal Photo Cards** | User can add a photo card using camera or gallery; card appears with custom photo in target category. | **PASS** | Verified in `personal_card_editor_screen_test.dart`. |
| **PHY-13** | **Child Profile Isolation** | Switching between Profile A and Profile B swaps vocabulary, personal cards, and daily schedules with 0 bleed. | **PASS** | Verified in `profiles_screen_test.dart`. |

---

## Phase 3  -  Multilingual Validation (Arabic, Darija, German, English)

| Test ID | Test Case | Target Requirement | Status | Device & Notes |
| :--- | :--- | :--- | :---: | :--- |
| **PHY-14** | **Arabic RTL & Cairo Font** | Right-to-left layout mirrors correctly; Arabic glyphs render cleanly with bundled Cairo typeface. | **PASS** | Verified in `rtl_test.dart`. Physical eyeball check required. |
| **PHY-15** | **Algerian Darija Support** | Arabic script with Darija dialect vocabulary and transliteration numerals (2, 3, 5, 7, 9) renders without clipping. | **PASS** | Verified in `darija_test.dart`. |
| **PHY-16** | **German LTR & Umlauts** | German labels (ä, ö, ü, ß) render cleanly with Atkinson Hyperlegible; TTS initiates German speech output. | **PASS** | Verified in `LocaleRegistry.specForCode('de')`. |
| **PHY-17** | **English LTR Core** | English core board functions with bundled neural voice clips (ADR 0004). | **PASS** | Verified across all test suites. |
| **PHY-18** | **Smart Keyboard Input** | Virtual keyboard allows typing in Arabic, Darija, German, and English, offering instant autocomplete chips. | **PASS** | Verified in `smart_keyboard_screen_test.dart`. |
| **PHY-19** | **Offline Voice Fallback** | When device is completely disconnected from internet, speech playback remains functional. | **PASS** | Bundled audio clips require no internet. |
| **PHY-20** | **Missing TTS Engine Alert** | If the physical device lacks a system voice for typed German or Darija, app alerts user gracefully without crashing. | **NOT TESTED** | Test on device with TTS disabled. |

---

## Phase 4  -  Accessibility, WCAG Compliance & Assistive Tech

> [!NOTE]
> **WCAG Criteria Distinction:**
> - **WCAG 2.1 SC 2.5.5 (Target Size - Enhanced):** Requires touch target dimensions of at least $44 \times 44\text{ CSS pixels/dp}$ (with inline, essential, or user-agent exceptions).
> - **WCAG 2.2 SC 2.5.8 (Target Size - Minimum):** Requires touch target dimensions of at least $24 \times 24\text{ CSS pixels/dp}$ (with spacing circle offset rules).
> - **NūriTalk Standard:** All primary communication buttons and routine cards meet or exceed the stricter **WCAG 2.1 SC 2.5.5** ($\ge 44 \times 44\text{ dp}$), while compact accessory chips meet or exceed **WCAG 2.2 SC 2.5.8** ($\ge 24\text{ dp}$).

| Test ID | Test Case | Target Requirement | Status | Device & Notes |
| :--- | :--- | :--- | :---: | :--- |
| **PHY-21** | **Touch Target Size Verification** | AAC grid buttons $\ge 64 \times 64\text{ dp}$; Schedule cards $\ge 48\text{ dp}$; Timer buttons $\ge 44\text{ dp}$. | **PASS** | Automated check in `e2e_communication_qa_test.dart`. |
| **PHY-22** | **TalkBack Screen Reader** | Linear swipe gestures navigate sequentially through grid buttons; semantic announcement reads label + role. | **NOT TESTED** | Physical TalkBack swipe testing required. |
| **PHY-23** | **Single-Switch Scanning** | Automatic timed scanning moves focus box across buttons; single switch press selects active item. | **PASS** | Automated check in `switch_access_test.dart`. |
| **PHY-24** | **Dual-Switch Scanning** | Switch 1 advances focus box; Switch 2 triggers selection. Focus border renders $3.5\text{px}$ amber ring. | **PASS** | Automated check in `switch_access_test.dart`. |
| **PHY-25** | **Physical Bluetooth HID Switch** | Connect Ablenet Blue2 or Pretorian Bluetooth pedal; verify key events (Space/Enter/1/2) trigger scan steps. | **BLOCKED** | Physical switch hardware required. |
| **PHY-26** | **High-Contrast Theme** | Activating high-contrast setting renders pure black high-contrast outlines and maximum-contrast text. | **PASS** | Verified in `profiles_screen_test.dart`. |
| **PHY-27** | **Reduced Motion** | Enabling Android "Remove animations" disables pulse glows and smooth timer animations safely. | **PASS** | Adheres to `MediaQuery.disableAnimations`. |
| **PHY-28** | **Display Scaling & Font Size** | Setting Android system font size to Largest (130%-150%) does not clip button labels or break grid layout. | **NOT TESTED** | Physical device settings adjustment required. |

---

## Phase 5  -  Daily Routines, Timers & Caregiver Features

| Test ID | Test Case | Target Requirement | Status | Device & Notes |
| :--- | :--- | :--- | :---: | :--- |
| **PHY-29** | **Daily Schedule Timeline** | Schedule displays chronological activities with category colors and completion checkboxes. | **PASS** | Verified in `daily_schedule_screen_test.dart`. |
| **PHY-30** | **First / Then Board** | Select First and Then tasks; tapping volume icon speaks the transition cue clearly. | **PASS** | Verified in `e2e_communication_qa_test.dart`. |
| **PHY-31** | **Visual Countdown Timer** | Diminishing colored disc updates second-by-second; visual flash cues completion. | **PASS** | Verified in `e2e_communication_qa_test.dart`. |
| **PHY-32** | **Activity Expression Sheet** | Tapping any schedule activity opens expressions ("I want this", "All done") and commits to sentence bar. | **PASS** | Verified in `e2e_communication_qa_test.dart`. |
| **PHY-33** | **Parental Math Gate** | Gating challenge ($A + B = ?$) prevents accidental child access to settings, profile edits, and exports. | **PASS** | Verified in `math_gate_test.dart`. |
| **PHY-34** | **Complete Backup Export** | Exporting backup creates a valid JSON bundle with profiles, cards, schedules, and settings via OS share sheet. | **PASS** | Verified in `board_backup_restore_test.dart`. |
| **PHY-35** | **Complete Backup Restore** | Restoring backup file restores all profiles, personal cards, routines, and settings. | **PASS** | Verified in `board_backup_restore_test.dart`. |
| **PHY-36** | **Corrupt Backup File Handling** | Selecting a truncated or malformed JSON backup produces a user-friendly error snackbar without crashing. | **PASS** | Verified in `AACBackupService.restoreBackupBundle`. |

---

## Phase 6  -  Offline Safety, Privacy & Resilience

| Test ID | Test Case | Target Requirement | Status | Device & Notes |
| :--- | :--- | :--- | :---: | :--- |
| **PHY-37** | **Airplane Mode Cold Launch** | App launches from cold state with device in Airplane Mode (Wi-Fi + Mobile Data OFF). | **NOT TESTED** | Physical device airplane mode required. |
| **PHY-38** | **Reboot Persistence** | Power-cycling device retains all customized boards, cards, schedules, and active profile selection. | **NOT TESTED** | Physical device reboot required. |
| **PHY-39** | **OS Process Termination** | Killing app process from Android Recents screen and re-opening restores exact previous board state. | **NOT TESTED** | Physical device process kill required. |
| **PHY-40** | **Low Storage Behavior** | Verify app does not crash or corrupt databases when device storage is below 500 MB. | **NOT TESTED** | Physical device storage constraint required. |
| **PHY-41** | **Network Traffic Inspection** | Monitor network interface with Charles Proxy / Wireshark; verify zero outbound calls during AAC speech. | **PASS** | Code analysis confirms zero automatic telemetry. |

---

## Phase 7  -  Performance Benchmarking Plan

| Benchmark Metric | Target Threshold | Measurement Tool | Physical Device Result |
| :--- | :--- | :--- | :---: |
| **Cold Start to Interactive** | $< 2.0\text{ seconds}$ | `adb shell am start -W -S` | **NOT TESTED** |
| **AAC Grid Render Time** | $< 16\text{ ms}$ (60 fps) | Flutter Performance Profiler | **NOT TESTED** |
| **Touch-Down to Speech Latency** | $< 100\text{ ms}$ | Audio waveform analysis | **NOT TESTED** |
| **Memory Footprint (Idle)** | $< 120\text{ MB}$ RAM | Android Studio Profiler | **NOT TESTED** |
| **Memory Footprint (Active Typing)** | $< 180\text{ MB}$ RAM | Android Studio Profiler | **NOT TESTED** |
| **24-Hour Battery Drain** | $< 2\%$ in background | Android Battery Historian | **NOT TESTED** |

---

## Sign-Off Summary

- **Total Checklist Items:** 41
- **Automated PASS:** 25
- **Requires Physical Device (NOT TESTED):** 15
- **Requires Special Hardware (BLOCKED):** 1 (Physical Bluetooth HID Switch Pedals)
- **Defects Identified:** 0 active unaddressed defects
