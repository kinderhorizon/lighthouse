# ADR 0006: Thompson sampler and glow rendering architecture

**Status:** Accepted
**Date:** 2026-05-28

## Context

ADR 0003 locked the cold-start strategy, the observation-count-aware visual
thresholds, the hitbox geometric invariant, and the onboarding flow. It did
NOT specify how the bandit actually samples, how predictions are produced
per frame, or how the glow gets on screen without harming the grid. Phase 3
(sessions 13 to 20) built those, and this ADR records the load-bearing
decisions so a future maintainer does not "optimize" them into regressions.

The bandit is a Contextual Multi-Armed Bandit with one Beta(α, β) posterior
per (stateKey, buttonId) pair. ADR 0003 set the update rule (PRD 3.2
gentle-penalty) and the cold-start prior (α = 2 × base_weight,
β = 2 × (1 - base_weight)). What remained: how to turn those posteriors into
a top-K glow set on each frame, cheaply and correctly.

## Decision

### 1. Thompson sampling via Beta draws; Gamma sampler with a shape-boosting trick

Ranking is Thompson sampling: for each candidate button, draw one sample from
its Beta(α, β) posterior and rank by the draw. A button glows if its draw and
posterior mean clear the ADR 0003 thresholds.

We sample Beta(α, β) as `X / (X + Y)` where `X ~ Gamma(α, 1)` and
`Y ~ Gamma(β, 1)`. Gamma sampling uses Marsaglia and Tsang's squeeze method,
which is only valid for shape ≥ 1.

**The shape-boosting trick is load-bearing, not an optimization.** The
cold-start prior produces shapes well below 1: the board's `base_weight`
ranges down to ~0.05, so α can be as low as `2 × 0.05 = 0.1`. A naive
Marsaglia-Tsang implementation assumes shape ≥ 1 and silently returns garbage
(or loops) for shape < 1. We use the Stuart / Marsaglia identity:

```
if shape < 1:
    g = Gamma(shape + 1, 1)         # now shape+1 >= 1, valid for M-T
    u = Uniform(0, 1]
    return g * u^(1/shape)
```

A future contributor who deletes the `shape < 1` branch ("all our shapes look
≥ 1 in the tests I ran") breaks day-one ranking for every low-base_weight
button, which is most of the board. The unit test
`beta_sampler_test.dart` pins shapes down to 0.1 specifically to guard this.

The sampler takes an injected `Random`. Production passes a fresh non-seeded
RNG; tests seed for deterministic ranking. Box-Muller supplies the normal
draw inside the Gamma method; we discard the second Box-Muller value rather
than cache it (the bandit samples a few dozen times per frame at most, so the
caching micro-optimization is not worth the statefulness).

### 2. Ranking reads cold-start priors lazily; folders never rank

`BanditRanker.topK` fetches each candidate's row from the store; if no row
exists it synthesizes the cold-start prior in memory (it does NOT write a
row). This keeps "never observed" and "observed once" as distinct states and
avoids polluting Isar with a row per never-tapped button.

Folders are dropped before ranking. Navigating a folder is not a
communication act (ADR 0003), so a folder must never glow.

### 3. Per-frame predictions provider + the ContextEpoch invalidation pattern

`currentPredictionsProvider` (Riverpod) composes the stateKey from the
ContextManager + WiFi hash + settings locale, calls the ranker for the top
`kMaxGlows` (= 4) predictions, and is the single source the widget tree
consumes (`currentGlowProvider` derives the level map from it).

The subtle part: **the ContextManager mutates its in-memory state in place**
(`previousButtonId`, the semantic-context decay) when a tap is recorded.
Riverpod cannot observe an in-place mutation of an object it hands out, so a
naive `ref.watch(contextManagerProvider)` would never re-run after a tap and
the glow set would go stale.

The fix is the **ContextEpoch pattern**: a trivial integer provider that the
predictions provider watches. `_recordTap` calls `contextEpoch.bump()` AFTER
it has advanced the ContextManager, which invalidates the predictions
provider and forces a fresh top-K under the evolved context. This keeps the
ContextManager pure-Dart and testable (no Riverpod dependency inside it)
while still giving the UI a reactive signal. A maintainer who removes the
`bump()` call will see glows freeze after the first tap; one who tries to make
ContextManager a Notifier instead is fighting the "logic layer stays
framework-free" boundary for no benefit.

Snapshot timing is also load-bearing: `_recordTap` reads the predictions
(for the gentle-penalty branch) and composes the stateKey BEFORE calling
`ContextManager.recordTap`, so the bandit observes the pre-tap state the
child actually acted on, not the post-tap state. Reordering these is a silent
correctness bug (penalty applied against the wrong context).

### 4. Glow is a decorative paint layer, never a layout participant

`GlowEffect` wraps a tile and paints over it (BoxShadow for pulse/halo, a
ColorFilter matrix for brightness). It must not change the tile's size or
position. A glow that reflowed the grid would move buttons a child relies on
by muscle memory: a regression worse than no glow. The widget test asserts
the child's measured size is identical with and without glow.

Three styles (ADR 0003 § 4) share one level state machine and differ only in
paint:
- `pulse` (default): a ~1.4s half-sine breath via an AnimationController.
- `halo`: a static golden ring.
- `brightness`: luminance + saturation boost, no border.

Reduced motion (`MediaQuery.disableAnimations`) downgrades `pulse` to `halo`
automatically. This is a sensory-safety requirement, not a nicety: some of the
children Lighthouse serves are motion-sensitive.

### 5. Reset learned state semantics

`BanditRepository.clearAll()` wipes both Isar collections in one transaction;
`ContextManager.reset()` clears the volatile half. The Settings flow runs
clearAll first, then reset, then invalidates the prediction providers and
bumps the epoch so the glow recomputes from the now-empty store. Order is
chosen for crash-window safety: a cleared Isar with a stale in-memory context
is harmless (the next tap rebuilds context), whereas the reverse could leave
a live context pointing at wiped rows.

## Consequences

- The sampler, the ranker, the predictions/epoch providers, and the
  GlowEffect widget are all governed by this ADR. Changes cross-reference here.
- Test coverage shipped: `beta_sampler_test` (shape < 1, LLN mean, determinism,
  asymmetry), `bandit_ranker_test` (cold-start synthesis, folder exclusion,
  ordering, determinism), `glow_level_test` (every threshold band boundary),
  `glow_effect_test` (style dispatch, reduced-motion downgrade, no layout
  shift), and the on-device `integration_test` end-to-end loop
  (taps → real Isar posteriors → ranker reads back → clearAll → cold prior).
- Performance: ranking is O(candidates) Beta draws once per stateKey change
  (not per frame, not per tap-while-context-unchanged). For the 48-button core
  board this is ~48 draws, negligible.

## Hitbox tap-target expansion (implemented)

`AACGrid` uses the internal-padding model: the GridView delegate spacing is
zero, each cell carries a `spacing / 2` internal padding, and the grid's
outer padding is pulled in by `spacing / 2` to compensate. The rendered
layout is pixel-identical to a normal spaced grid (the math cancels exactly).
A glowing tile shrinks its internal padding by
`HitboxExpansion.perSideExpansion`, growing its Material/InkWell into the dead
gap WITHOUT moving any neighbor (no layout shift) and WITHOUT exceeding the
gap (two adjacent glowing tiles at Maximum meet exactly, never overlap, per
the ADR 0003 § 3 invariant). Verified by `aac_grid_hitbox_test.dart` (real
layout-engine getRect/getSize, host) AND `integration_test/glow_grid_test.dart`
(the same geometric assertions run on the device binary, iPad Pro 11-inch M4
sim), plus an on-device layout render screenshot.

## Open items (not yet implemented)

- None blocking. (Hitbox wiring closed above.)

## Alternatives considered

- **Uniform-random or argmax-of-posterior-mean ranking instead of Thompson.**
  Argmax is greedy: it never explores, so a button that started with a low
  prior can never recover even if the child's needs shift. Thompson sampling's
  exploration is the entire point of a bandit over a lookup table. Rejected.
- **A normal approximation to the Beta posterior** (mean ± sd) to avoid Gamma
  sampling. Breaks exactly where it matters: the cold-start regime has tiny
  shapes where the Beta is highly skewed and the normal approximation is poor.
  Rejected.
- **Caching predictions on a timer instead of the epoch bump.** A timer adds a
  staleness window and a wakeup cost for no benefit; the epoch bump is exact
  (fires precisely when context changed) and free. Rejected.
- **Making ContextManager a Riverpod Notifier** so watchers re-run naturally.
  Rejected: it drags framework types into the pure-logic layer, and the epoch
  pattern achieves the same reactivity from the outside.

## Reviewers

- Engineering review: proposed 2026-05-28
- Independent reviewer,
  Phase 3 review 2026-05-28: approved the architecture; specifically validated
  the shape-boosting trick, the snapshot timing, the layout-decorative glow,
  and the reduced-motion fallback; directed that this ADR document the
  ContextEpoch invalidation pattern and the BetaSampler shape-boosting trick
  for future maintainers (both captured in § 1 and § 3).
- Independent reviewer, final written-ADR sign-off
  2026-05-28: reviewed `docs/adr/0006`, moved it from Proposed to Accepted;
  audited the Reset-learned-state order-of-operations (Isar wipe before
  volatile context, provider invalidation + epoch bump) as correct for
  crash-window safety; instructed on-device visual verification of the hitbox
  InkWell behavior, satisfied by `integration_test/glow_grid_test.dart`.
- Clinical lead (BCBA): glow styles, default-on golden pulse,
  and reduced-motion behavior consulted under ADR 0003; no new clinical
  surface introduced here.
