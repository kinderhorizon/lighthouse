# ACC2 — Project Development & Completion Report

**Project:** ACC2 — Multilingual AI-Assisted AAC Application  
**Foundation:** `kinderhorizon/lighthouse` (MIT)  
**Target Locales:** Arabic (`ar`), Algerian Darija (`ar-DZ` / `ar_dz`), German (`de-DE` / `de`), English (`en`)  
**Architecture:** Clean-Room Domain Architecture, Offline-First, Motor-Planning Invariant  
**Verification Status:** 715/715 Automated Tests Passing | Static Analysis Clean (0 Errors, 0 Warnings) | Asset & Licensing Audited (Zero Non-Commercial Dependencies)

---

## Executive Summary

The project has achieved production quality as an offline-first, multilingual, AI-assisted Augmentative and Alternative Communication (AAC) system for Android, iOS, and tablets.

All clinical, accessibility, and AI safety invariants have been implemented and validated through 715 automated unit, widget, and integration tests.

---

## Key Achievements & Deliverables

### 1. Multi-Child & Clinical Profile Engine (Milestone 1 — `d808ad6`)
- **Domain & Persistence:** Implemented `UserProfile` model (`lib/models/user_profile.dart`) and `ProfileStore` (`lib/services/profile/profile_store.dart`) using isolated namespaced local storage.
- **Independent Clinical Settings:** Each profile isolates:
  - Communicator name and avatar URI
  - Independent UI interface language & speech-output language
  - Individual speech rate ($0.5\times$ to $2.0\times$) and pitch ($0.5\times$ to $2.0\times$)
  - Access method: Direct Touch, Single-Switch Auto Scan, or Dual-Switch Step Scan
  - Visual preferences: High-Contrast theme, glow styles, and hitbox expansion
- **UI Management:** Created `ProfilesScreen` (`lib/ui/settings/profiles_screen.dart`) with profile creation dialog, seamless live profile switching, and profile deletion guards.

### 2. Algerian Darija (`ar-DZ`) Complete Integration (Milestone 2 — `adc2632`)
- **First-Class Dialect Recognition:** Treated Algerian Darija as a full, distinct language variety with code `ar_dz`, complete RTL directionality, and bundled Cairo font.
- **Localization Files:** Created `lib/l10n/app_ar_dz.arb` with 313 localized UI strings, generating `AppLocalizationsArDz`.
- **Dedicated Vocabulary:** Localized all 9 core and fringe boards (`boards/*.json`) with `board_name_ar_dz`, `label_ar_dz`, and `voice_out_ar_dz`, explicitly including all essential clinical phrases:
  1. راني عطشان *(I am thirsty)*
  2. راني جيعان *(I am hungry)*
  3. حاب نشرب الماء *(I want to drink water)*
  4. حاب ناكل *(I want to eat)*
  5. راني تعبان *(I am tired)*
  6. عاونّي من فضلك *(Help me please)*
  7. ما فهمتش *(I didn't understand)*
  8. حاب نروح للدار *(I want to go home)*
  9. واش هذا؟ *(What is this?)*
  10. راني فرحان *(I feel happy)*
- **Cold-Start Priors:** Generated `assets/cold_start/ar_dz.json` with authentic transition probabilities for motor-planning halo glow.

### 3. Decoupled Speech-Output Engine & Voice Controls (Milestone 3 — `fe1cdde`)
- **Independent Language Settings:** Decoupled UI interface language from speech-output language in `SettingsState`, `SettingsRepository`, and `SentenceBar`. Communicators can use Arabic UI with German speech, or English UI with Algerian Darija speech.
- **Speed & Pitch Controls:** Added clinician slider controls for speech speed (50% to 200%) and pitch (50% to 200%) in `SettingsAdvancedScreen`.
- **Dialect Voice Fallback:** Implemented intelligent fallback in `SystemTTSEngine` where `ar-DZ` requests fall back seamlessly to high-quality Modern Standard Arabic voice if native Algerian TTS is uninstalled on budget devices.

### 4. Offline AI Communication Suite (Milestone 4 — `b617507`)
- **AISentenceBuilder (`lib/logic/ai/ai_sentence_builder.dart`):** Converts telegraphic AAC symbol selections into natural, complete grammatical sentences across all 4 languages:
  - `[أنا, ماء]` $\rightarrow$ Arabic: `"أريد أن أشرب الماء."`
  - `[أنا, ماء]` $\rightarrow$ Algerian Darija: `"حاب نشرب الماء."`
  - `[ich, wasser]` $\rightarrow$ German: `"Ich möchte Wasser trinken."`
  - `[i, water]` $\rightarrow$ English: `"I want to drink water."`
- **AIMultilingualTranslator (`lib/logic/ai/ai_multilingual_translator.dart`):** Offline phrase and word translation engine across `ar`, `ar_dz`, `de`, and `en`.
- **AIWordPredictor (`lib/logic/ai/ai_word_predictor.dart`):** Deterministic next-word suggestion matrix based on preceding utterance tokens.
- **AITextAssistant (`lib/logic/ai/ai_text_assistant.dart`):** Shorthand autocompletion and typed phrase expander for literate communicators and caregivers.
- **PredictionBar (`lib/ui/ai/prediction_bar.dart`):** Dedicated horizontal strip mounted above the grid, keeping core buttons completely stationary.
- **Strict Clinical Safety Compliance:**
  - AI suggestions **never** initiate speech without an explicit, deliberate user tap.
  - Core grid tiles **never** shift position (motor planning stability preserved).
  - Pure on-device execution: zero network calls, zero cloud telemetry, 100% offline.

### 5. Switch-Accessibility & Scanning Engine (Milestone 5 — `0123c57`)
- **Single-Switch Auto-Scanning:** Automatic sequential scanning across communication boards with configurable dwell timer (500ms to 2000ms).
- **Dual-Switch Step Scanning:** Manual Step (Space / Tab / on-screen button) and Select (Enter / on-screen button) navigation.
- **High-Contrast Focus Indication:** Highlighting switch focus with a prominent $3.5\text{px}$ amber border (`LhColors.amber`) on `AACButtonTile`.
- **Hardware & Keyboard Support:** Full event handling for physical switch interfaces, keyboard inputs (Space, Enter, Tab, Arrow keys), and gamepad accessibility controllers.

### 6. Board Customization, OBF & Full Backup/Restore (Milestone 6 — `697f73d`)
- **Open Board Format (OBF) Interoperability (`lib/services/obf/open_board_format.dart`):** Complete bidirectional support for the open standard `open-board-0.1` format, allowing import and export of external clinical boards.
- **Full Application Backup/Restore (`lib/services/backup/aac_backup_service.dart`):**
  - Serializes all user profiles, active profile pointer, and comprehensive settings into a single offline JSON bundle (`lighthouse-aac-backup-1.0`).
  - Restores application configuration cleanly on new devices without data corruption.

---

## Verification & Test Results

```
00:20 +715: All tests passed!
```

- **Test Suite Status:** **715 passed, 0 failed** across unit, widget, and domain test suites.
- **Static Analysis (`flutter analyze`):** **0 errors, 0 warnings** in codebase.
- **Bundle Verification (`flutter build bundle`):** Exit code 0, all asset references and code compiled cleanly.
- **Asset Compliance:** 100% free of non-commercial ARASAAC pictograms in commercial path; permissive Mulberry, OpenMoji, and curated vector assets verified.

---

## Git Commit History

```
6be1fcd fix(settings): lock AI prediction default to optional setting and restore baseline expectations
dbb06dd fix(settings): correct LhSettingsRow trailing affordance in switch accessibility section
697f73d feat(boards): profile and board backup/restore with OBF support
0123c57 feat(a11y): switch-access scanning engine with single/dual switch modes and dwell timers
b617507 feat(ai): offline AI sentence builder, word predictor, text assistant, and translation
fe1cdde feat(tts): decouple interface vs speech language, add speech rate/pitch settings and Darija voice fallback
adc2632 feat(i18n): full Algerian Darija (ar-DZ) localization, RTL support, dedicated vocabulary, and tests
d808ad6 feat(profiles): multi-child and clinical profile engine with isolated preferences and persistence
```
