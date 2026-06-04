# App integration spec: context-aware cold-start prior

Audience: the Lighthouse coder. Reviewer (read-only) authored this; implement and
the reviewer will QA against it. Scope is small and surgical by design.

## Goal

Replace the **context-blind** cold-start prior with a **context-aware** one. The
bandit already keys learning on `stateKey` which contains `Prev:btn_id`; only the
*cold-start prior* ignores it. We feed the prior a per-`(locale, prevButtonId,
candidateButtonId)` mean `w'` built offline (see this folder's README), so the
glow is sensible from tap 1.

Non-goals: no change to Thompson sampling, glow thresholds, the learning update
rule, prior strength (stays 2), tile positions, or the persisted schema.

## The artifact

`build_prior.py` emits `out/<locale>.json`. The `transitions` VALUES are derived
by a multilingual causal language model (PMI), per locale; `provenance` in the
file records the exact model. The app does not care how they were produced -- it
consumes the same schema regardless:

```json
{
  "schema_version": 1,
  "locale": "en",
  "board_version": "1.3",
  "prior_strength": 2.0,
  "status": "MODEL_GENERATED",
  "transitions": {
    "_NONE":   { "btn_i": 0.72, ... },          // sentence start (no prev)
    "btn_eat": { "btn_more": 0.85, "btn_happy": 0.15, ... },
    ...
  },
  "fallback": "absent (prev,cand) -> app uses the button base_weight"
}
```

Bake the three files in as assets, e.g. `assets/cold_start/{en,es,ar}.json`, add
them to `pubspec.yaml`. (Later candidate for OTA delivery via the existing signed
manifest; key it per locale + board_version. Not now.)

The values are model-generated (no clinical review step). The safety net is
structural: it is a cold-start prior that washes out with use and only changes
which tiles glow, never their position. Ship it.

## Where it plugs in

Two call sites compute the cold-start prior. They MUST stay identical (the
docstring in `lib/logic/bandit/cold_start_prior.dart` already warns about this:
if the ranker scores under one prior and the updater seeds under another, a
button is ranked and learned inconsistently). Both must become context-aware.

1. `lib/logic/bandit/bandit_ranker.dart` - the no-row branch currently does:
   ```dart
   final prior = coldStartPrior(button.baseWeight);
   ```
2. `lib/logic/bandit/bandit_updater.dart` - where it seeds a fresh cold-start
   row for a `(stateKey, buttonId)` on first observation (same `coldStartPrior`
   call). Update it the same way.

### Proposed shape

Add a resolver that both sites share:

```dart
// lib/logic/bandit/contextual_cold_start.dart
class ContextualColdStart {
  ContextualColdStart(this._transitions); // Map<String, Map<String,double>>

  final Map<String, Map<String, double>> _transitions;

  /// w' for (prev, candidate), or null to fall back to base_weight.
  double? meanFor({required String prevKey, required String candidateId}) =>
      _transitions[prevKey]?[candidateId];
}
```

Then the prior mean at both call sites becomes:

```dart
final prevKey = prevButtonId ?? '_NONE';
final w = ccs.meanFor(prevKey: prevKey, candidateId: button.id)
        ?? button.baseWeight;          // fallback == today's behaviour
final prior = coldStartPrior(w);       // SAME Beta shape + clamp + strength
```

`coldStartPrior` itself does not change. Its clamp stays load-bearing (the
artifact clamps to [0.05, 0.95] but defence-in-depth at the app boundary is
correct, since a future artifact or an OTA-delivered one is less trusted).

### Deriving `prevButtonId` (agreement guarantee)

Both call sites operate on the same `stateKey`, and `stateKey` contains the
`Prev:` segment. Parse `prevButtonId` out of the stateKey at both sites with one
shared helper, so they can never disagree:

```dart
// "TimeBlock_DayType|Wifi|Prev:btn_eat|Context:food" -> "btn_eat" (or null)
String? prevButtonIdFromStateKey(String stateKey);
```

(Alternatively pass `ContextManager.previousButtonId` in; parsing the key is
preferred because it is the one value both sites already share.)

### Deriving `locale` (which artifact)

`locale` is NOT in `stateKey`. Resolve it the same way `glow_provider.dart`
already does: `LocaleRegistry.effectiveLocale(settings.localeOverride)`, then
load that locale's artifact (provider below). Pass the resolved
`ContextualColdStart` into the ranker and updater.

Edge case - locale switch mid-learning: a `(stateKey, buttonId)` row seeded under
locale A's prior could later be ranked while locale B is active. Acceptable: the
prior is a cold-start seed of weight 2 that washes out with real observations,
and the persisted row is already locale-agnostic. Do NOT add locale to stateKey
(that is a heavier V1->V2 migration) unless QA shows a real problem.

### Loading

A `keepAlive` provider loads the active locale's asset once, parses to
`Map<String, Map<String,double>>`, and exposes `ContextualColdStart`. On a
missing/unsupported-locale asset, return an empty map -> every lookup falls back
to `base_weight` -> exactly today's behaviour. Fail safe, never throw. The map
lookup is O(1); rank cost is unchanged.

## Interaction with `semantic_boost.dart` (ADR 0011)

The prior subsumes most of the curated boost (after "Eat", food now ranks high
via the prior; after "Want", feelings/responses are suppressed via the prior).
But the existing boost also force-glows the **folder** that leads to a sub-board
(eat -> Food folder), and the ranker never ranks folders. Recommendation:

- Phase 1: KEEP `semantic_boost` as-is. The prior augments on-board ranking; the
  verb->folder force-glow keeps pointing INTO sub-boards. They are complementary
  (the prior also covers eat->apple, which fires once the child is on the food
  board, because folder navigation does not record a tap so `Prev:` stays
  `btn_eat`). CONFIRMED: `main.dart` (~line 270) routes a folder tap to
  `_handleFolderTap` and returns BEFORE `_recordTap`, so `Prev:` is not advanced
  by navigation - eat->apple will fire on the food sub-board. (If that tap
  handling ever changes to record folder taps, this property breaks; add a guard
  test so it cannot regress silently.)
- Phase 2 (optional, later): consider retiring `kPostVerbSuppressedCategories`
  once QA confirms the prior's suppression covers it, to remove duplication.

## Known property, not a bug

High-`base_weight` safety words (Help, Stop at 0.9; Bathroom 0.8) can still glow
shimmer/gold in contexts where they are suppressed, because suppression is
multiplicative on odds and their base is very high (e.g. "go help" / "go stop").
This is arguably desirable - a distressed child should always reach Stop/Help.
If undesired in specific contexts, pin those pairs lower in `proposals.json`
and rebuild (pins apply by default).

## Tests to add

- Prior fallback: missing asset / unknown `(prev,cand)` -> uses `base_weight`
  (parity with current behaviour). 
- Ranker/updater agreement: extend the existing shared-prior invariant test so
  both use `ContextualColdStart` and produce the identical Beta for the same
  `(stateKey, buttonId)`.
- Port the offline golden frames (`data/golden.json`) to a Dart widget/unit test
  on the built artifact: after `btn_eat`, food/`more` glow and
  feelings/responses/questions do not; after `btn_want`, suppression holds; etc.
- Motor-planning invariant unchanged: assert no code path reorders tiles (prior
  affects glow only).

## Invariants preserved (reviewer will check these)

- Tiles never move; glow is display-only.
- Learned rows still win once observations exist (prior only governs no-row).
- Prior strength stays 2 -> observation-count glow thresholds undisturbed.
- Folders still excluded from ranking.
- `coldStartPrior` clamp intact (NaN / 0 / 1 protection).
- No new egress, no new permission, no telemetry. The artifact is a bundled
  static asset; nothing about the child leaves the device. ADR 0002 holds.
