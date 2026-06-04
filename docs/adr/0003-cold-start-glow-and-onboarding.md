# ADR 0003: Cold-start glow algorithm, settings, and onboarding

**Status:** Accepted
**Date:** 2026-05-28

## Context

The "Glow" system highlights the buttons a child likely wants to tap based on
current context (TimeBlock, DayType, WifiHash, PrevButtonID, SemanticContext).
The underlying model is a Contextual Multi-Armed Bandit using Thompson Sampling.

On day one of installation, the bandit has zero per-child observations. Naive
uniform-prior Thompson Sampling would produce essentially random rankings until
the child has accumulated enough taps. We need a strategy that makes the first
session feel alive without over-promising authority the model does not have.

Three concerns shape the decision:

1. **False positives cost more in AAC than in most products.** A wrong-confident
   glow trains the child to look at the wrong button, adds cognitive load, and
   can train wrong muscle memory. Wrong-confident is worse than no-glow.
2. **The first 50 taps are real attempts at communication.** The child cannot
   tell us whether the model is wrong; their feedback IS the taps. We should
   not be cavalier about that regret window.
3. **Parents and clinicians watching over the child's shoulder need visible
   evidence of learning over time.** A glow set that grows and personalizes is
   itself a feature; a static day-1 glow that never changes is less compelling.

A related question is whether to bootstrap the cold-start via parent-led
onboarding. Existing AAC apps (Proloquo2Go, TouchChat) ship guided onboarding
flows that walk parent and child through example taps to seed the model. That
pattern has structural problems for the population Lighthouse is built for
(see Alternatives section).

## Decision

### 1. Bandit prior (weak)

Initialize each (state, button) pair with:
- `α = 2 × base_weight` (from `boards/core_main.json`)
- `β = 2 × (1 - base_weight)`

Pseudo-observations sum to `α + β = 2`, which is a weak prior. Real taps
dominate within ~50 observations. Buttons with high `base_weight` get a small
nudge into glow territory on day one; the bandit corrects this quickly as real
data arrives.

### 2. Visual confidence thresholds (observation-count-aware)

The PRD specifies posterior mean thresholds for gold and shimmer states. We
amend these to vary by the number of real observations the bandit has for the
specific (state, button) pair:

| Observations | Gold threshold | Shimmer threshold |
|---|---|---|
| 0 | ≥ 0.75 | ≥ 0.50 |
| 1-3 | ≥ 0.70 | ≥ 0.40 |
| 4-10 | ≥ 0.65 | ≥ 0.35 |
| 10+ | ≥ 0.60 | ≥ 0.30 (PRD defaults) |

Same single bandit, same weak prior. Higher thresholds at low observation counts
reduce false-positive cost during the prior-dominated window. Shimmer still
fires across the board so the app feels alive; gold is earned over time.

The visible effect for parents and clinicians: the gold set starts small (a few
high-base_weight needs-row items) and grows and personalizes as the child uses
the app. That growth is itself a feature, visible evidence of learning that
no day-1 glow can provide.

**Maximum simultaneous glows:** 3-4 buttons at any moment, per PRD.

### 3. Hitbox expansion (geometric constraint)

A glowing button gets an invisibly expanded tap target to assist motor planning.
The expansion is bounded by the inter-button margin, halved:

```
max_expansion = min(padding_x, padding_y) / 2
```

This is load-bearing. The PRD permits 3-4 buttons to glow simultaneously and
adjacent glowing buttons are possible. Halving the margin guarantees that two
expanded hitboxes can never overlap, preserving the "Augment, Don't Rearrange"
invariant. A future contributor who "optimizes" this to the full margin is
silently shrinking non-glowing neighbors' targets when an adjacent button
glows, a regression. A code comment and a unit test in
`test/geometry/hitbox_expansion_test.dart` enforce the invariant.

**Settings semantic labels (not percentages):**
- None
- Subtle (uses 50% of the geometric maximum)
- Maximum (uses 100% of the geometric maximum)

**Default:** Subtle.

### 4. Glow visual style

Settings toggle exposes three visual modes (clinical input,
2026-05-28):
- Pulsing golden glow (default)
- Static halo
- Brightness-boost only

All three implement the same posterior-mean-driven gold/shimmer state machine;
they differ only in animation. Default to pulsing golden glow.

### 5. Onboarding flow (30-45 seconds, all-optional, per-question skippable)

Replaces the original (III) parent-prior-seeding proposal after the cross-
context-bias concern was raised in review.

**Screen 1, Grid familiarization.** Render Home Core 48 to the parent. Tapping
a tile plays the TTS audio and animates the button. No data seeding. Pure
grid literacy.

**Screen 2, Q2 (context-label question).** "Where does your child use the
device most?" → Home / School / Both / Other. This labels the first-seen WiFi
SSID hash for parent-facing UI ("at school, your child asks for X most"). The
bandit's behavior is identical with or without it.

**Screen 3, Privacy claim.** "Everything you've just told us, and everything
your child does next, stays on this device. Lighthouse never sends data
anywhere." A `(?)` icon opens a short architecture explainer (no cloud, no
third-party SDK, manual-share-only crash logs per ADR 0002).

Skipping is per-screen. The "Done" button is always available.

### 6. Settings architecture (two-tier, math-gated advanced)

**Primary tier (no gate):**
- Volume
- Share crash logs
- View crash logs
- Locale

**Clinician / Advanced tier (math gate, "5 + 7 = ?"):**
- TTS mode (On / On-request / Off / ALS)
- Glow style (pulsing / halo / brightness)
- Hitbox expansion magnitude (None / Subtle / Maximum)
- Re-run onboarding
- Reset learned state (with confirmation warning)

**Math-gate threat model (documented to prevent over-engineering):**
The math gate blocks:
- Accidental access from a non-speaking child's exploration taps
- Accidental settings changes during regular use

The math gate does NOT block:
- A numerate child who decides to figure it out
- An intentionally curious child of any age

By design. The gate is friction, not security. Future contributors must not
"harden" it (PIN, biometric, harder arithmetic), that breaks parent ergonomics
without addressing a real threat.

## Consequences

- **Code structure:** the bandit, the visual mapping, the hitbox geometry, and
  the onboarding flow are all influenced by this ADR. Changes to any of them
  warrant cross-referencing here.
- **Test coverage required:**
  - Hitbox geometric invariant test (no two expanded hitboxes overlap)
  - Cold-start visual threshold table behavior at each observation count band
  - Onboarding flow skip-from-any-screen behavior
- **Telemetry coupling:** crash logs include `unique_context_keys_count` (ADR
  0002) partly to detect bandit context-key cardinality explosions, which
  would invalidate the cold-start assumptions here. If we see > 10,000 keys in
  a crash log, that's a bug or an unanticipated context expansion.

## Alternatives considered

### Cold-start strategy

- **(a) Strong prior, always-on glow.** Day 1 looks authoritative but is
  authoritative about a population average, not a child. False positives during
  the 50-tap regret window are costly. Rejected.
- **(b) Glow off until N observations per state.** Honest but reads as broken
  to a parent watching the device on day 1. Rejected.
- **(c) Pink-row-only glow at cold start.** Engineering-honest but reads as
  anxious; clinicians who want needs-row priority don't care if it's a
  hardcoded rule or an emergent behavior. The amended (d), weak prior plus
  observation-count-aware thresholds, produces the same first-week visual
  effect (mostly Pink row buttons glowing) without committing to the
  architecture restriction. Subsumed.

### Onboarding

- **(II) Joint-attention onboarding (Proloquo2Go style).** Hard reject.
  Requiring joint attention as a setup prerequisite selects against the
  population the app was built for. The kids who most need Lighthouse are the
  least able to finish a joint-attention task. The alpha cohort would skew
  toward kids with stronger joint-attention baseline (the least informative
  group for testing the product's actual value proposition). Family abandonment
  in the first five minutes becomes a leading cause of failed installs that we
  would never see in our data. Future contributors must not propose this as a
  "growth experiment."

- **(III) Parent-selected phrase prior-seeding** (originally proposed; revised).
  Rejected after review. A parent's selections of "5 favorite phrases" would
  globally bias the bandit across all contexts (poisoning Morning, School,
  Night, etc. equally), violating the contextual learning premise of the
  bandit. Parent-reported preferences are also a poor signal for actual child
  usage. Replaced with the grid-familiarization screen (current Screen 1),
  which captures the grid-literacy benefit without the data-quality problem.

- **(IV) Delayed opt-in onboarding** ("after 50 taps, offer setup"). Parked
  for v1.0 if alpha shows real abandonment. Not in MVP scope.

### Settings architecture

- **Tabbed Settings ("Voice & Feedback" / "Visual Help" / "Advanced").**
  Considered. Rejected because parents under stress don't read tabs, and tabs
  do not address the child-accidentally-changing-settings concern. Math-gate
  split addresses both.

## Reviewers

- Engineering review: proposed 2026-05-28
- Independent reviewer: reviewed 2026-05-28,
  caught the cross-context prior-poisoning issue in original (III), proposed
  hitbox geometric constraint, proposed observation-count-aware thresholds
- Engineering review (second pass): tightened to current text 2026-05-28
- Independent reviewer (final pass): reviewed 2026-05-28, refined Q1/Q2
  honest framing (Q1 dropped, Q2 reframed as context-label not prior-seeding)
- Clinical lead (BCBA): consulted on TTS modes, glow style,
  default board content, base weights, terminology, hitbox magnitude. Approved
  2026-05-28.
