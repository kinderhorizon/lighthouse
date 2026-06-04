# ADR 0008: Localization architecture + launch languages (en, ar, es)

**Status:** Accepted
**Date:** 2026-05-28 (accepted after independent review 2026-05-28)

> Accepted after an independent review of the load-bearing calls (Arabic
> register, the translation-review bar, the Arabic TTS strategy) by a reviewer
> other than the author. The alpha-exit native + clinical sign-off of the
> Arabic + Spanish `voice_out` words (see Reviewers) remains a separate gate.

## Context

English, Arabic, and Spanish are the launch languages. The persistence,
board, and TTS layers were already locale-aware before this work:

- `AACButton` stores `labelByLocale` / `voiceOutByLocale` (parsed from
  `label_<code>` / `voice_out_<code>` JSON keys) with `labelFor` /
  `voiceOutFor` falling back to the default. Tiles and both tap paths
  (production + onboarding) already resolve by `Localizations.localeOf`.
- `SystemTTSEngine.speak` already calls `setLanguage(bcp47)` per locale and
  exposes `supports(locale)`; `FallbackTTSEngine` already selects an engine.
- `supportedLocales` already lists en/ar/es; Global Material/Widgets/Cupertino
  delegates already flow `TextDirection.rtl` from the locale.

So this was never a re-architecture. The real gaps were: (1) no app-string
localization pipeline at all (no `l10n.yaml`, no ARB, ~60 hardcoded English
strings); (2) no translated board vocabulary; (3) no completeness guards.

## Decision

### Extensibility is the spine, not a later cleanup

Adding the Nth language (LTR or RTL) must be a **data operation**, not a code
edit. Four invariants enforce this:

1. **One locale registry is the single source of truth.** `lib/i18n/locale_registry.dart`
   holds one declarative entry per locale: `code`, `textDirection`,
   `ttsStrategy` (`systemOnly` / `bundledClips` / `selfRecorded`),
   `requiredFontFamily`, and `reviewStatus` (`provisional` / `nativeReviewed`).
   `supportedLocales`, the resolution callback, the TTS engine picker, and the
   tests all derive from this table. Adding a locale = one registry entry + an
   ARB file + board JSON keys + (where required) bundled clips. Zero widget or
   logic edits.
2. **Tests iterate the registry, never name a locale.** Parity and
   board-completeness checks loop over the registry's locales and assert
   `forall locale: keys(en) subset of keys(locale)`. A test written as
   "en and ar and es" silently stops covering locale #4; written as a
   quantifier it extends itself.
3. **No `if (locale == 'ar')` anywhere.** Direction keys off
   `Directionality.of(context)`; spacing/alignment uses
   `EdgeInsetsDirectional` and logical properties only. Custom painters
   (glow, hitbox, the onboarding coachmark pointer) are audited against this:
   they must read text direction, not a language code. This is what makes the
   next RTL language (e.g. fa, ur) a non-event.
4. **`label` and `voice_out` stay independent per locale.** Already true in
   the model; no shortcut may collapse them. The on-tile word and the spoken
   word legitimately differ (the English `I` -> `eye` pronunciation hack; the
   Arabic bare-script label vs diacritized voice_out). This independence is
   also what lets review be a pure data edit.

### Launch-language rulings

- **Arabic register: Modern Standard Arabic (MSA) for v1.** Universally
  taught, written, and understood; dialect choice would fragment the audience
  and multiply review cost. Documented limitation. Dialects (ar-EG, ...) are
  future registry entries, which the registry design keeps clean. AAC favors
  comprehensibility and consistency over colloquial nuance.

- **Arabic diacritics (tashkeel): bare script in `label`, diacritized in
  `voice_out`.** Tiles read naturally; the spoken/pre-rendered audio gets
  correct vowelization. No new engineering (the label/voice_out split exists);
  it is a content task for the Arabic reviewer.

- **Arabic TTS = bundled pre-rendered clips as the PRIMARY path, not
  system-TTS.** The 48 core words are a tiny finite set. Many Android devices
  ship no Arabic system voice, so a system-TTS-only Arabic launch would make a
  tile tap produce silence, which is the highest-severity failure mode for an
  AAC app. We therefore build-time pre-render the core vocab (per the project
  TTS strategy: neural pre-render via cloud TTS, single-digit-dollar cost,
  bundle the audio) and route Arabic core taps through bundled clips on every
  device regardless of OS voices. System TTS + a parent "install a voice"
  prompt + show-text-large are the fallback-of-the-fallback for free-typed
  text only. **We do not ship Arabic on a system-TTS-only path.** If that
  sequencing genuinely cannot hold, shipping the silent-tap failure mode must
  be an explicit, recorded reversal of this ADR, never a default.

- **Translation-review bar = alpha-exit criterion, not a merge gate.**
  Clinical/native review does not block engineering or alpha. MT + LLM-drafted
  translations (UI strings AND the 48 `voice_out` words) ship to alpha marked
  `provisional` in the registry. Before the **public store release to families
  at scale**, the 48 `voice_out` words (highest-stakes, smallest set) must be
  native + clinically (BCBA) signed off and flipped to `nativeReviewed`. The
  `provisional` flag makes "what still needs review" queryable at alpha time.
  This respects "don't block engineering" while keeping the child's unreviewed
  voice out of the general public release.

### Pipeline

Flutter `gen_l10n`: `l10n.yaml` + `lib/l10n/app_<code>.arb`, generating
`AppLocalizations` (non-nullable getter). `AppLocalizations.delegate` is added
to the delegate list; `supportedLocales` and a `localeResolutionCallback`
(unsupported -> en) derive from the registry. Every hardcoded `Text('literal')`
becomes an `AppLocalizations` lookup; enum-to-label helpers take the localized
strings rather than returning English literals.

## Consequences

- Adding a language is: registry entry + ARB + 48 board key-sets + clips. The
  CI parity + completeness tests then force that set to be complete.
- We carry `provisional` translations through alpha; the registry is the
  audit surface for the alpha-exit review.
- Arabic launch is coupled to the core-vocab pre-render pipeline landing (the
  bundled-clips primary path). Spanish, which has near-universal system voice
  coverage, can run system-TTS while also benefiting from clips later.
- Font coverage becomes a per-locale registry concern (Arabic shaping).

## Open items the independent review should attack

1. MSA-for-v1: defensible for an AAC child's expressive voice, or does it read
   as stilted enough to matter?
2. Alpha-exit (not merge-gate) review bar: right balance, or too lax for the
   child's spoken voice even at alpha?
3. Bundled-audio-primary for Arabic: agree it is mandatory, or is a
   well-handled system-TTS + install-prompt acceptable for v1?
4. Any LTR/RTL-agnostic invariant gaps in the registry shape.

## Reviewers

- Engineering review: 2026-05-28. Authored the architecture and the
  extensibility invariants; verified the existing locale-aware layers in code.
- Product / decisions: 2026-05-28. Ruled MSA (4.2), alpha-exit review bar
  (4.1), bundled-audio-primary for Arabic (4.3), font + coachmark + math-gate
  digit smoke items.
- Independent reviewer: reviewed 2026-05-28 (a reviewer other than the author);
  approved the rulings, status flipped Proposed -> Accepted.
- Clinical lead (BCBA): owns the alpha-exit native+clinical
  sign-off of the 48 Arabic + Spanish `voice_out` words.
