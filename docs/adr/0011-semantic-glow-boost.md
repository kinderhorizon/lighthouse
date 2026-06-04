# ADR 0011: Semantic glow boost (verb -> object highlighting)

Status: Accepted (2026-05-29)

## Context

The glow predictions (ADR 0003 / 0006) are a usage bandit: they learn what a
specific child taps next and start near-flat, so on a fresh device the
highlights look arbitrary. Clinical-lead alpha feedback asked
for highlights that make grammatical/semantic sense from day one: "after eat
highlight food, after drink highlight water, after want highlight the words the
kid uses most." That last clause is the bandit's job; the first two are a
fixed verb -> object association the bandit cannot know cold.

## Decision

1. **A small curated verb -> object-category table** (`kVerbObjectBoosts`,
   keyed on stable button id): eat/drink -> food(+folder), go -> places,
   play -> activities, look/open -> things. Verbs with no clear object domain
   (want / need / like / get / make) are deliberately absent and fall through
   to the bandit, exactly matching the clinical lead's "after want, most-used."

2. **Display-layer only.** The boost is applied in `currentGlow` (what the grid
   shows), not in `currentPredictions` (the snapshot the bandit learns from).
   So semantic guidance never pollutes the learning signal: the child's real
   taps still drive the posteriors.

3. **Last word drives it.** The boost reads the last token in the sentence bar
   (ADR 0010). After the verb is tapped, the matching buttons on the *current*
   board are force-glowed gold. Auto-clear on speak (ADR 0010) naturally ends
   the boost.

4. **Folders can glow when boosted.** ADR 0003 says folders never glow because
   navigation is not a communication act. Scoped exception: after "eat" on the
   home board, the Food *folder* is exactly what the child should be guided to,
   so a boosted folder glows. This is display guidance, not a bandit row.

5. **Defer to the bandit when the boost is uninformative.** If the current
   board has more matching buttons than the glow cap (we are already inside the
   target sub-board, e.g. the Food board after "eat"), boosting half the grid
   is noise, so we fall back to the bandit's most-used ranking within that
   category.

## Consequences

- Meaningful highlights on day one without waiting for the bandit to train,
  while the bandit still personalizes over time (boost guides to the folder;
  usage ranks within it).
- The table is hand-maintained; new verbs/categories need an entry. A future
  refinement could derive associations from board metadata.
- Authored by the implementer; independent technical review per the project
  ADR cadence.
