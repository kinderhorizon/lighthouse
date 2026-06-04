# ADR 0010: Sentence bar (utterance composition)

Status: Accepted (2026-05-29)

## Context

Until now Lighthouse spoke one self-contained `voice_out` per tap and (inside
a sub-board) auto-returned home (ADR 0009). There was no accumulation: tapping
"Want" then "Help" spoke two unrelated canned phrases. Clinical-lead alpha
feedback (clinical review) asked for the standard AAC interaction:

- Each button still sounds out its word on tap (immediate feedback).
- Taps accumulate into a sentence shown in a strip along the top.
- An explicit "speak" action replays the **corrected** full sentence.
- Two verbs in a row should read with an infinitive link ("want **to** go").

This is the keystone interaction; the feelings-phrasing decision (#2/#11) and
the grammar-aware highlights (#3) both build on it.

## Decision

1. **Utterance state.** A `keepAlive` Riverpod notifier holds an ordered
   `List<AACButton>` (the tapped tokens, not strings, so chips can show the
   pictogram and we can re-resolve labels per locale). Methods: `append`,
   `backspace`, `clear`.

2. **Tap behavior.** A word/phrase tap (the communication act, per the current
   TTS-mode rules in ADR 0004) now also appends its button to the utterance.
   On-request mode appends on the long-press, matching where the act already
   lives. The single-word speak-on-tap is unchanged; auto-return-home (ADR
   0009) is unchanged and the bar **persists across board navigation**, which
   is what makes "I" (home) + "want" (home) + "apple" (Food folder) accumulate
   into one sentence.

3. **Composition.** A pure function `composeUtterance(tokens, languageCode)`
   produces the spoken string from the tokens' `voiceOutFor(languageCode)`:
   - capitalize the first word;
   - **English only**: insert "to" between two consecutive `verb`-category
     tokens (item #7). Romance/Arabic infinitive linking differs and carries
     no "to", so the rule is locale-gated rather than wrong everywhere.
   Full grammaticalization (articles, agreement, conjugation) is explicitly
   **out of scope for alpha**; the composer is a pure, unit-tested seam we can
   grow rule by rule without touching call sites.
   - **Documented next step:** the "to" rule currently fires on any verb pair.
     The verified board data has no modals tagged `verb`, so it is correct on
     the common catenatives (want/need/like + verb) and only mildly
     over-applies ("go to play"). Tighten later to an infinitive-taking-verb
     allowlist (want/need/like/try) rather than a change now.

4. **Replay = concatenated per-word clips, not synthesized sentence.** The
   "speak" control composes the ordered word list (`composeUtteranceTokens`)
   and calls `TTSEngine.speakSequence`. The bundled engine plays each token's
   existing per-word clip to completion in order; `FallbackTTSEngine` routes a
   sentence to whichever single engine can speak **every** token, so a sentence
   made entirely of board words (always true in Arabic) stays on the bundled
   path. This is deliberate: routing the climactic replay (the child presenting
   their whole message) to system TTS would silently undercut ADR 0008, which
   made bundled audio mandatory for Arabic precisely because system Arabic TTS
   is unreliable and a silent utterance is the worst AAC failure. System TTS is
   used only as a whole-sentence fallback when a token has no clip (e.g. an
   inserted English "to" before its clip is rendered in #109). Trade-off:
   concatenated clips are choppy (no sentence intonation); smooth prosody was
   already deferred to Piper, and choppy-and-correct beats smooth-and-silent.

5. **Always on for alpha.** No disable toggle yet (the clinical lead asked for
   the behavior outright). A clinician switch is a fast-follow if a pure
   single-word-learner profile needs it.

6. **Lifecycle / overflow.** The bar **auto-clears after speak** (clinical review,
   2026-05-29): once the replay finishes playing, the sentence resets for the
   next message, preventing accidental run-on accumulation. Mid-build editing
   is still manual: backspace removes the last token, clear empties. When the
   sentence outgrows the strip it scrolls horizontally (newest token visible);
   no truncation, no token cap for alpha.

## Consequences

- Composition is locale-aware but minimal; non-English "to" handling and
  feelings-as-bare-word-vs-phrase are deferred to the phrasing pass (#109).
- The bar adds vertical chrome above the grid; the grid keeps the remaining
  space. Fine on a tablet; on a phone (Android sideload self-test is imminent)
  the bar will crowd the grid. Not alpha-blocking (families get tablets), but
  expect it on the phone.
- `speakSequence` is now part of the `TTSEngine` interface, implemented by all
  four engines (bundled concatenates clips; system speaks the joined string;
  Piper stub throws; fallback orchestrates coverage).
- This ADR was authored by the implementer and revised after the independent
  independent technical review: Decision 4 was rewritten
  from synthesized-sentence to concatenated-clip replay on that review's
  ADR-0008 grounds.
