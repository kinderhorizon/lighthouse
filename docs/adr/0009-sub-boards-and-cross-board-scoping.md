# ADR 0009: Fringe sub-boards, home-board restructure, and cross-board bandit scoping

**Status:** Accepted
**Date:** 2026-05-29 (accepted after independent review 2026-05-29)

## Context

The home board (Home Core) shipped with 8 folders that linked to sub-boards
that did not exist, so every folder tap surfaced a "pack not loaded" message. A
folder that goes nowhere is a broken utterance for a non-speaking child, so the
sub-boards have to exist for alpha. Building them forced three decisions, two of
which are *structural* (motor patterns that freeze the moment a child learns
"where a word lives", so they must be set well before alpha while there are zero
users and changing them is free) and one of which is an *architecture
correctness* question about how the learning layer behaves once there is more
than one board.

This separation matters: per ADR 0008 the *quality* of translations and the
*choice* of fringe words are reversible content, refined with the clinical lead
after alpha and never a merge gate. But board structure, grid, button positions,
folder taxonomy, and navigation defaults are the one class where pre-alpha is the
only cheap moment.

## Decision

### 1. Question words are core: home-board restructure (structural)

Every reference AAC system (Project Core's 36 universal words, Proloquo,
TD Snap Core First, WordPower) keeps the question words *what / where / who /
when / why / how* on the home board, not behind a folder. We promoted them to
the home board's top row and **removed the Questions folder**. This required
growing the home grid from 6x8 to **7x8** (the only board that is not 6x8;
column count stays 8 so reach is consistent). The board was renamed "Home Core
48" to "Home Core" since it is no longer 48 buttons. Made now, pre-alpha, while
repositioning harms no one.

### 2. Seven fringe sub-boards (structure fixed now; words provisional)

The remaining folders (Food, Places, People, Activities, Things, Feelings,
Time) each become a bundled **6x8** board with roughly 16 frequency-ranked,
semantically clustered words and empty slots (we deliberately do not fill the
grid; quality over quantity). Vocabulary is drawn from the standard AAC fringe
category sets, not invented, and ships **provisional** in en / es-US (Latin
American) / ar (MSA). Translation quality and final word selection are the
clinical lead's to refine after alpha, asynchronously, never blocking
engineering (ADR 0008). Time was re-scoped to calendar/time fringe and Feelings
to expanded emotions (the core feelings stay on the home board).

### 3. Auto-return to home after a communication act (structural default)

The sentence pattern is core-verb (home) then fringe-noun (sub-board). After a
word is spoken inside a sub-board the app returns to the home board
automatically, so the next core word is one tap away and a child is never
stranded in a folder (also softens that sub-boards have no in-grid back tile).
Precedent: WordPower. It is a clinician-configurable setting
(`settings.autoReturnToHome`), **default on**. It does not fire on a silent
On-request tap (the long-press is the act there) and is a no-op at the root.

### 4. Cross-board bandit / glow scoping (architecture correctness)

The contextual bandit's state key is
`timeBucket_dayType | wifi | Prev:prevButtonId | Context:semantic` and
deliberately **does not include board identity**. Posterior rows are keyed by
`(stateKey, buttonId)`, and the ranker only ranks the active board's candidate
buttons. Because **button IDs are globally unique and each button appears on
exactly one board**, every posterior is already board-scoped through its
buttonId: a food word's statistics can only ever be observed or ranked on the
food board. There is therefore no cross-board bleed, and adding `board_id` to
the key would be redundant and would needlessly fragment learning (worse
cold-start). The carry-over of the `Prev:` n-gram across a folder hop (for
example "want" then "cookie") is a useful sequential signal, not a bug.

The correctness of this rests entirely on the uniqueness invariant, so it is
enforced by a test (`board_integrity_test`): button IDs are unique across every
board, and every folder `link_id` resolves to a registered board on disk
(the no-dead-folder gate). State space grows linearly in the number of buttons,
not combinatorially, so adding boards does not threaten the ADR 0005 schema.

**Future caveat:** if we ever place the same word on more than one board with a
shared button ID (the WordPower pattern of embedding common core inside category
pages, to bridge core and fringe and preserve motor planning), the uniqueness
invariant breaks and `board_id` (or button position) MUST then enter the state
key, or one board's learning will bleed into another's glow. We do not do this
for alpha; the test will fail loudly if someone introduces it.

## Consequences

- Adding a sub-board is a data operation: a `boards/board_*.json` file, a
  pubspec asset entry, a row in `BoardRegistry`, then the pictogram and clip
  pipelines (`fetch_symbols`, `generate_clips`) which now iterate every board.
- The non-recursive pubspec asset rule bit a third time: the new pictogram
  subdirectories (activities, things, time, questions) and the board JSONs are
  each enumerated explicitly, and `verify_assets` plus the manifest tests cover
  every board, not just the home board.
- All pre-rendered clips ride the existing TTS pipeline (ADR 0004 amendment):
  the same Laomedeia voice across en / es / ar, with the loudness guard.
- Home-board muscle memory is now committed: question words and folder
  positions should not move after alpha without accepting the motor-planning
  cost that "buttons never move" exists to prevent.

## Alternatives considered

- **Hide or disable the folders for alpha.** Rejected: alpha exists to get
  feedback on the real product; shipping dead folders wastes the signal.
- **Keep Questions as a folder.** Rejected: question words are the highest-value
  core words; burying them contradicts every reference system and would freeze a
  bad motor pattern.
- **Add `board_id` to the bandit state key "to be safe".** Rejected: redundant
  given unique IDs, and it fragments posteriors (worse cold-start) for no gain.
- **Per-category grid sizes.** Rejected: consistent grids preserve motor
  planning; only the home board deviates (7 rows) to fit the promoted core row.

## Update (2026-05-29): symbol QA, grid completion, provenance

Initial sub-board pictograms were selected by taking the top ARASAAC keyword
hit without looking at the image. That shipped multiple wrong-sense symbols
(homonyms: "cracker" as a party firework, "pool" as billiards, "park" as a
parking lot; partial matches: "ice cream" as an ice cube, "soon" as a flute;
form mismatches: "rice"/"cereal" as the raw crop; an i18n leak: "weekend" with
Spanish day-letters baked in). Lesson, now a standing rule:

- **Select symbols by looking, not by keyword.** A visual contact sheet (every
  icon rendered above its word, per board) is generated and reviewed for every
  board; wrong senses are fixed with an explicit pictogram-id override in
  `tools/fetch_symbols.dart` after verifying the actual image. Depict the
  referent in the form the child communicates about (food as eaten, places as
  the location, not the actor/verb), and resolve homonyms by meaning.
- **Provenance is mandatory** (ADR 0001): every symbol records its
  `arasaac_id`, search keyword, and sha256. The sub-board symbols had none;
  `fetch_symbols` now carries provenance forward on skip and backfills it, and
  all symbols are attributed.
- A few abstract relational words with no clean, distinct ARASAAC art were
  dropped for alpha rather than shipped confusable ("soon", "after", "cousin"),
  and "almost" was earlier replaced by "late". Communicative value, not symbol
  availability, picks the word; these are reversible and revisited with curated
  art.

Grid completion: the home board's three trailing empty cells were filled with
real vocabulary, not filler. The deictic core words "here" and "that" join the
question row, and an eighth fringe folder, **Body** (16 concrete body parts,
pairing with the "Hurt" core word for pain localization), completes the folder
row. The home grid is now 56/56.

## Reviewers

- Engineering: authored the plan and the implementation 2026-05-29.
- Independent reviewer: reviewed 2026-05-29 (a reviewer other than the author);
  caught that the home board was full (forcing the explicit restructure) and
  that cross-board bandit scoping was unaddressed, and approved the resolution.
  Status set to Accepted.
- Clinical lead (BCBA): refines fringe word lists and translations after alpha,
  asynchronously; not a gate on this decision.
