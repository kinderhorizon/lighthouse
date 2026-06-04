# ADR 0004: Text-to-Speech strategy

**Status:** Accepted
**Date:** 2026-05-28

## Context

Lighthouse AAC needs Text-to-Speech (TTS) to vocalize button taps. TTS quality
varies dramatically by platform, manufacturer, and locale. The launch language
matrix (en, ar, es Tier 1; fa, fr, ja, he, ur, hi Tier 2) compounds the problem:
- English TTS is excellent everywhere
- Spanish TTS is good everywhere
- Arabic TTS is good on iPad, acceptable on Samsung Galaxy Tab, worse on
  budget Android tablets
- Farsi and Urdu TTS are functional but robotic on most devices

The alpha device matrix is constrained: iPad (Apple TTS via AVSpeechSynthesizer)
plus Galaxy Tab (system TTS via Google or Samsung engine). Both are
acceptable-to-good for Tier 1 languages.

We also have to decide whether to ship a fallback neural TTS engine (Piper)
bundled in the APK to handle locales where system TTS is weak.

## Decision

### MVP: system TTS only

Use `flutter_tts` wrapping iOS AVSpeechSynthesizer and Android TextToSpeech.
Zero bundle weight cost, zero infrastructure, zero additional licensing
considerations. Quality is acceptable across the alpha device/locale matrix.

### Architectural seam: TTSEngine interface from day one

All TTS call sites in `lib/` go through an abstract `TTSEngine` interface:

```dart
abstract class TTSEngine {
  Future<void> speak(String text, {required Locale locale});
  Future<bool> supports(Locale locale);
  Future<void> stop();
  Future<void> dispose();
}
```

Implementations:
- `SystemTTSEngine`, wraps `flutter_tts` (MVP, the only one shipped in MVP)
- `PiperTTSEngine`, stubbed for Phase 2 (returns false from `supports()`)
- `FallbackTTSEngine`, composite, delegates by locale-support priority

This costs an hour upfront and saves a week when Phase 2 lands. Without it,
swapping in Piper later touches every speech call site in the codebase.

### Voice-output behavior (four modes, Settings-driven)

Per the clinical lead (BCBA) 2026-05-28:

| Mode | Behavior | Use case |
|---|---|---|
| **On** (default) | Device speaks every tap | Proloquo2Go-style default; most users |
| **On-request** | Long-press to speak | Auditory-sensitive children; child wants explicit control |
| **Off** | No synthesized speech | Aided Language Stimulation (parent voices) or fully silent use |
| **ALS / Parent voicing** | Selected word shown large on screen for the parent to voice aloud; no TTS | Explicit AAC pedagogy (SCERTS framework, ALS protocols) |

Settings location: Clinician/Advanced tier (math-gated, see ADR 0003 §
Settings).

### Phase 2 trigger (Piper bundled fallback)

Built into the alpha feedback flow: a TTS-quality survey ("rate the voice
quality 1-5 per session, per locale"). If any (device, locale) pair averages
below 3 across alpha sessions, that pair becomes a Piper target for Phase 2.

Piper integration involves native bindings, voice caching (20-60 MB per voice),
locale-to-voice mapping, memory management, and substantial testing. Estimated
30-40 hours of engineering when triggered. Not on the MVP critical path.

## Consequences

- Adding Piper later is a one-class swap behind the interface, not a
  cross-cutting refactor.
- The four-mode voice-output behavior is wired in MVP via Settings, even
  though three of the modes are clinically rare. Implementation is cheap
  because all four are gating logic on the same speak() call.
- "Reset learned state" in Settings does NOT reset TTS preferences, those
  are user preferences, not bandit state.
- We are not investing in voice quality engineering for MVP. If alpha families
  complain about Arabic TTS on Galaxy Tab specifically, that's the kind of
  signal that triggers Phase 2 sooner rather than later.

## Alternatives considered

- **(A) System TTS only, no abstraction.** Simplest. Rejected because the
  Phase 2 swap cost is real and the abstraction is cheap.
- **(B) Ship Piper bundled from day one.** Rejected. 30-40 hours of engineering
  for a problem we have no evidence exists in the alpha device matrix. Building
  voice quality infrastructure before validating product-market fit is a
  classic over-investment pattern.
- **(C) Cloud TTS** (Google Cloud TTS, Amazon Polly, ElevenLabs). Rejected
  by architecture. Cloud TTS requires network calls, breaking the "no data
  ever leaves the device" promise (ADR 0002 + brand-voice). The audio
  payload would be a covert channel for "what the child wanted to say,"
  which is exactly what we promised not to transmit.

## Reviewers

- Engineering review: proposed 2026-05-28
- Independent reviewer: reviewed 2026-05-28; added the
  `TTSEngine` interface seam recommendation
- Clinical lead (BCBA): clinical input on four-mode voice
  output behavior including the ALS / Parent-voicing mode 2026-05-28

---

## Amendment (Accepted, 2026-05-28): bundled pre-rendered audio is the primary path

**Status of this amendment:** Accepted after independent review 2026-05-28 (a
reviewer other than the author). The original MVP decision above also stays
Accepted; this amendment supersedes its "system TTS only" choice for the fixed
core vocabulary.

### What changes

The original decision shipped **system TTS only** and listed cloud TTS as
"rejected by architecture" because a runtime cloud call would leak what the
child wants to say (ADR 0002). That reasoning holds for *runtime* synthesis.
It does **not** apply to *build-time* synthesis: the core vocabulary is a small
finite set (40 word/phrase buttons x en/es/ar = 120 clips today), so we can
pre-render every clip once, at build time, on the maintainer's machine, and
**bundle the audio**. No network call ever happens on-device, so the
"no data ever leaves the device" promise is fully intact.

New default speech path:

1. **Bundled clip** (primary) for any tapped core-vocabulary word/phrase.
2. **System TTS** (`flutter_tts`) fallback for free-typed text, or any
   (locale, word) with no clip yet.
3. **Show-text-large + "install a voice" prompt** (last resort) when neither
   can speak. (Tier 3 is a call-site UI follow-up; with clips present for all
   core vocab it only matters for free-typed text in a locale whose device has
   no system voice.)

The `TTSEngine` seam absorbs this without touching call sites: a new
`BundledAudioTTSEngine` joins the existing `FallbackTTSEngine` chain. The one
interface change is that capability is now **per-utterance** (`canSpeak(text,
locale)`) rather than per-locale (`supports(locale)`), so the bundled engine
can claim a tapped core word while yielding free-typed text to system TTS in
the same locale.

### Decisions recorded

- **Provider: Google Cloud Text-to-Speech**, for credit + license: Cloud TTS
  terms permit shipping synthesized output inside a distributed app, clean for
  the public OSS repo. The API key is a maintainer build-time secret, never
  committed.
- **Bundled audio is MANDATORY (not optional) for Arabic** (carries ADR 0008
  ruling 4.3 forward): many Android devices ship no Arabic system voice, and a
  silent tap is the single worst failure for an AAC app. Arabic must not ship
  on a system-TTS-only path. The Arabic core-vocab render must land with or
  before Arabic's public launch.
- **All launch locales (en, es, ar) are bundled**, not just Arabic: a
  consistent warm neural voice across the board beats each device's default
  robotic voice. Driven by `ttsStrategy: bundledClips` in the locale registry
  (the single source of truth); `en`/`es` were flipped from `systemOnly`.
- **Per-word clips only.** Smooth full-sentence prosody (concatenation /
  Piper dynamic synthesis) stays deferred; no sentence logic here.
- **Format: MP3.** Cloud TTS cannot emit AAC/M4A; MP3 plays natively on both
  iOS and Android under `just_audio` with no transcode. (The brief's "AAC
  default" is not achievable directly from Cloud TTS; MP3 is the correct
  zero-transcode choice and is recorded here as the deliberate deviation.)
- **Voice persona is clinical-lead-gated.** Two-phase: render candidate voices
  for audition (`tools/tts/candidates/`), the clinical lead picks one voice per
  locale, then render the full set. Until reviewed, clips are `provisional`.
- **Integrity.** `assets/audio/manifest.json` records each clip's sha256,
  voice_id, and provenance. `tools/verify_assets.dart` recomputes every clip's
  sha256 and asserts each clip's parent directory is actually bundled by
  `pubspec.yaml` (the same non-recursive-asset trap that hid the ARASAAC
  pictogram gap, db95f85).

### Consequences

- Bundle size grows by the clip set (~120 short MP3s at launch). Acceptable for
  the offline-privacy + reliability guarantee.
- The generator (`tools/tts/generate_clips.dart`) is maintainer-run, never on a
  normal build. Procedure in `tools/tts/README.md`.
- Piper (the original Phase 2 idea) becomes a *later* path for dynamic / free
  text, not for the fixed vocabulary, which bundling now covers better.

### Cost

The full en/es/ar render is ~120 clips / a few thousand characters, a one-time
build-time cost that is negligible at the chosen voice tier (account-specific
budget details are tracked in the maintainer's internal notes, not here). It
was rendered without minting an API key; the generator authenticates via a
maintainer gcloud token.

