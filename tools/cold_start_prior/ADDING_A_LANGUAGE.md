# Adding a new language to the cold-start prior

Worked example: **Urdu (`ur`)**. Substitute your locale code throughout.

This runbook is the canonical "add a language" process for the glow cold-start
prior. It has a tool part (this directory) and an app part (the Flutter side).
There is no clinical/SLP review step by design; the safety net is structural
(a cold-start prior washes out with use and only changes which tiles GLOW, never
their position), and the automated golden gate catches gross nonsense.

---

## Mental model: what "a language" actually needs

The prior is `w'(locale, prevButtonId, candidateButtonId)`. To produce a good one
for a new locale you need four things, in order:

1. **Board labels in that language** (`label_ur` / `voice_out_ur` on every
   button). Without them the tool scores ENGLISH words inside the new-language
   frames -> garbage. This is the real prerequisite and the bulk of the work.
2. **A model that covers the language.** The default `bigscience/bloom-1b7`
   covers 46 languages including Urdu, Arabic, Spanish, English. If you add a
   language BLOOM was not trained on, pick a multilingual model that includes it
   (`--model ...`) or the scores are noise. Verify coverage before trusting output.
3. **Per-language carrier frames** (`data/frames.json`) written naturally in that
   language. See the SOV caveat below - this is the subtle part.
4. **App locale support** so the device can run in that locale and the loader
   requests `assets/cold_start/ur.json`.

---

## Part 1 - Board content (prerequisite, app-data side)

For every button in every `boards/*.json`, add the locale fields:
`label_ur`, and `voice_out_ur` for word/phrase buttons (folders need only
`label_ur`); add `board_name_ur` per board. This mirrors the existing
`*_es` / `*_ar` fields. ~172 buttons across 9 boards.

Quality here is everything: the model only knows the words you give it. A
machine translation is a starting point, but have a competent speaker sanity-read
the labels (this is normal localization, not a specialist gate).

Urdu is **right-to-left** (Arabic script), like Arabic - the app already handles
RTL, but see "Broader language launch" for the font note (Urdu typically wants a
Nastaliq face, not the Naskh `Cairo.ttf` bundled for Arabic).

---

## Part 2 - The prior tool (this directory)

### 2.1  Register the locale suffix

`prior/board.py`, `LOCALE_SUFFIX`:

```python
LOCALE_SUFFIX = {"en": "", "es": "_es", "ar": "_ar", "ur": "_ur"}
```

### 2.2  Add carrier frames - `data/frames.json`

Each entry is `[with_prev_template, baseline_template]`. The tool scores the
string `with_template.format(p=<prev label>) + " " + <candidate label>`, and the
PMI is `logP(candidate | with) - logP(candidate | baseline)`. So the frame must
read naturally with **the candidate appended at the end**.

> **SOV / head-final caveat (READ THIS for Urdu, Hindi, Turkish, Japanese...).**
> English/Spanish are SVO, so "I want to eat" + "apple" -> "I want to eat apple"
> is natural and the model's next-word signal is strong. Urdu is **SOV**: the
> object precedes the verb ("I apple eat want"), so appending the candidate after
> a full verb clause is unnatural and weakens the signal. For head-final
> languages, prefer **short, word-order-robust frames** - the bare bigram does
> most of the work and does not fight word order:

```json
  "ur": [
    ["{p}", "۔"],
    ["میں {p}", "میں"]
  ]
```

(`میں` = "I"; `۔` is the Urdu full stop, used as the neutral baseline.) These are
a **starting point** - have an Urdu speaker confirm they read naturally, then
eyeball `out/review_ur.md` (step 2.5). If the output looks weak, iterate on the
frames before anything else; frames are the highest-leverage knob for a new
language.

### 2.3  Golden frames - `data/golden.json` (usually no change)

The golden frames key on button IDs and are language-universal (mostly
suppression: "off-topic must not glow"), so they apply to `ur` automatically.

If a *positive* expectation fails for `ur` only (the model genuinely does not
associate that pair in this language - exactly what happened with Spanish
`go -> outside`), do NOT force it. Either:
- scope the frame to the locales where it holds: add `"locales": ["en", "es"]`
  to that frame, or
- pick a more robust anchor (we use `go -> home`, which holds broadly).

A missing/weak pair simply falls back to `base_weight` (shimmer-eligible if the
base is >= 0.5), so the tile is still reachable.

### 2.4  Build

```sh
python3 build_prior.py --locale ur --model bigscience/bloom-1b7
```

Heartbeat prints every ~1.5s; runtime is a few minutes on MPS. PMI is cached per
`(locale, model, method)` under `out/_cache/`, so re-running to retune the
gate/calibration is instant.

### 2.5  Eyeball the output

Read `out/review_ur.md`. Sanity check the high-traffic contexts: after the verb
for "eat", do food words lead? After "want", are feelings/yes/no suppressed?
`out/golden_ur.txt` must say PASS (the build also exits non-zero on failure).

If it looks wrong, the usual culprit is frames (2.2) or missing/poor `label_ur`
(Part 1) - fix those and rebuild. The POS gate (`data/grammar_scaffold.json`) is
language-universal and rarely needs per-locale work; the optional manual
overrides (`data/proposals.json`, applied by default) are there if you must pin a
specific pair.

### 2.6  Ship the artifact

Copy the generated file into the app's assets:

```sh
cp out/ur.json ../../assets/cold_start/ur.json
```

`pubspec.yaml` registers `assets/cold_start/` as a **directory**, so a new file
in it is bundled automatically - no pubspec edit needed.

---

## Part 3 - App wiring (Flutter side; see INTEGRATION.md)

1. **Register `ur` as a supported app locale** in `lib/i18n/locale_registry.dart`
   (and the app's `supportedLocales` / l10n delegates). The cold-start loader
   (`lib/state/cold_start_provider.dart`) uses `locale.languageCode`, so once
   `ur` is selectable it will request `assets/cold_start/ur.json` on its own.
   If `ur` is NOT registered, the loader fails safe to `base_weight` (no crash),
   but the prior never activates - so this step is what turns the feature on.
2. **Add `ur` to the golden test** locale lists in
   `test/logic/bandit/contextual_cold_start_golden_test.dart` (the
   `['en','es','ar']` loops and the rootBundle bundling check) so the new
   artifact is held to the same contract and is verified to actually bundle.
3. No change to `cold_start_provider.dart`, the resolver, the ranker, or the
   updater - they are locale-generic.

---

## Part 4 - Verify (the checklist)

- [ ] `label_ur` / `voice_out_ur` on every button; `board_name_ur` per board.
- [ ] `ur` in `LOCALE_SUFFIX` (`prior/board.py`).
- [ ] `ur` frames in `data/frames.json`, speaker-checked for naturalness.
- [ ] `python3 build_prior.py --locale ur` -> golden PASS.
- [ ] `out/review_ur.md` eyeballed; on-topic leads, off-topic suppressed.
- [ ] `assets/cold_start/ur.json` copied; byte-identical to `out/ur.json`
      (`diff` them).
- [ ] `ur` registered in `lib/i18n/locale_registry.dart` + app supportedLocales.
- [ ] `ur` added to the golden Dart test loops.
- [ ] `flutter analyze` clean; full suite green; no em/en dashes in the artifact.

---

## Broader language launch (OUT OF SCOPE for the prior, but needed for the app)

Adding a language to the *app* is more than the prior. Track these separately:

- **UI strings:** `lib/l10n/app_ur.arb` (mirrors `app_es.arb` / `app_en.arb`).
- **Fonts:** Urdu prefers a **Nastaliq** typeface (e.g. Noto Nastaliq Urdu); the
  bundled `Cairo.ttf` (Naskh, for Arabic) renders Urdu but not idiomatically.
  Add the font in `pubspec.yaml` and the theme.
- **TTS / audio:** the app uses bundled audio per locale (`assets/audio/{en,es,ar}/`).
  Urdu needs its own audio set or a platform-TTS fallback for `ur`.
- **RTL:** already handled (Arabic), but smoke-test the Urdu board renders RTL.
- **Date/weekend semantics:** `ContextManager` day-type uses locale; confirm the
  Urdu/region weekend is correct if it matters for context separation.

---

## Why this stays cheap per language

The engine, the POS gate, the calibration, the golden contract, the resolver, the
loader, and the app integration are all language-generic. A new language adds
only: its board labels, one `LOCALE_SUFFIX` entry, one `frames.json` block, an
asset file, and one locale registration. No new code, no model retraining, no
schema or migration changes.
