# NūriTalk / ACC2  -  Android Release Blockers & Pre-Flight Conditions

**Document Version:** 1.0.0  
**Date:** October 19, 2026  
**Auditor:** Lead Flutter Engineer & AAC Accessibility Specialist  
**Application ID:** `org.kinderhorizon.lighthouse`  
**Version:** `1.0.3+14`  

---

## 1. Summary of Release Status

| Category | Readiness Status | Details |
| :--- | :---: | :--- |
| **Technical Codebase** | **PASS** | 751 / 751 automated tests passed (100% pass rate). 0 static analysis errors/warnings. |
| **Release Artifacts** | **PASS (QA ONLY)** | `app-release.apk` (72 MB) and `app-release.aab` (71 MB) built for QA; verified debug-signed. |
| **Fail-Closed Gradle Guard**| **PASS** | Unsigned release compilation blocked in <3s; silent debug fallback completely eliminated. |
| **Signing Audit CLI** | **PASS** | `tools/verify_android_signing.py` verified; flags current release artifacts as unsafe for Play Store. |
| **Physical Device Verification** | **BLOCKED** | No physical device connected to the build workstation. Physical testing required. |
| **Production Key Signing** | **BLOCKED** | Production keystore (`.jks`) provisioning required from organization. |
| **Overall Recommendation** | **CONDITIONAL** | Ready for physical-device pilot testing; blocked from direct public Play Store upload until physical checklist is signed off and production keystore configured. |

---

## 2. Active Pre-Flight Blockers (Must Be Completed Prior to Production)

### BLOCKER-01: Physical Hardware Device Verification
- **Status:** **BLOCKED**
- **Impact:** Critical (P0)
- **Description:** No physical Android phone or tablet was connected via ADB to this Linux development environment (`adb devices` returned 0 attached devices). Automated widget and integration tests cannot replace physical digitizer touch testing, hardware speaker acoustics, or real-world switch interfaces.
- **Resolution Criteria:** Complete all manual test items in `docs/qa/physical-device-test-checklist.md` on at least two physical Android devices:
  1. An Android tablet (10-inch, e.g., Samsung Galaxy Tab A9 or Lenovo Tab M10).
  2. A low-to-mid range Android phone running Android 11+ (API 30+).

### BLOCKER-02: Production Release Keystore Provisioning
- **Status:** **BLOCKED (Fail-Closed Guard Operational)**
- **Impact:** High (P1)
- **Description:** In accordance with the security architecture in `android/app/build.gradle.kts`, the production release keystore is not tracked in version control.
  - The current release binaries (`app-release.apk` and `app-release.aab`) were verified by `apksigner` and `keytool` as signed with `CN=Android Debug` (`A8D0FD2621042AD36E94B672339D7FDDF264E3C0A528DB783A86CB26C988D47E`).
  - Standard release compilation without a keystore now fails closed immediately with `GradleException: ERROR: PRODUCTION RELEASE BUILD BLOCKED - SIGNING KEY REQUIRED`.
- **Resolution Criteria:**
  1. The organization must provision the production upload keystore (`upload-keystore.jks`) and configure `android/key.properties` per `android/key.properties.example`.
  2. Build the production bundle: `flutter build appbundle --release --dart-define-from-file=config/release.json`.
  3. Verify with `python3 tools/verify_android_signing.py build/app/outputs/bundle/release/app-release.aab` (must return classification `PRODUCTION_SIGNED_UPLOAD_BUNDLE`).
  4. Never upload debug-signed binaries to the Google Play Store.

### BLOCKER-03: Real-World Assistive Switch Hardware Testing
- **Status:** **NOT TESTED**
- **Impact:** High (P1)
- **Description:** Software scanning logic and visual amber focus borders are fully verified by automated tests (`test/ui/switch_access_test.dart`). However, physical switch latency, debounce timing on Bluetooth HID pedals (such as Ablenet Blue2 or Pretorian USB interfaces), and TalkBack focus traps must be verified by a clinician or accessibility engineer with physical hardware.
- **Resolution Criteria:** Execute Phase 4 of `docs/qa/physical-device-test-checklist.md` with physical switch pedals.

---

## 3. Verified Non-Blockers (Resolved in this Cycle)

- **Regional Locale Resolution (`ar_dz`):** Resolved. `LocaleRegistry.specForCode` now ensures proper `Locale('ar', 'DZ')` instantiation and RTL layout direction.
- **Full AAC Backup & Restore:** Resolved. Full profile, card, schedule, and settings backup and restore is integrated into `settings_primary_screen.dart` and protected by the parental math gate.
- **Release Endpoint Guard:** Resolved. Tested with `--dart-define-from-file=config/release.json`.
- **Zero Telemetry & Local Sandbox Storage:** Resolved. Verified offline-first local persistence without unauthorized network calls.
