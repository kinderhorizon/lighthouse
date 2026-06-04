# ADR 0013: Home favourites (promote most-used / pinned to home)

Status: Accepted (2026-05-29)

## Context

Clinical-lead alpha feedback #10: the items a child requests most (e.g. one
favourite food buried in the Food sub-board) should be reachable from the home
page, "both" automatically and manually.

The naive read ("a strip whose auto half re-ranks by live tap frequency")
collides with the app's motor-planning foundation: fixed grid positions,
board-exclusive ids (ADR 0009), and glow-not-move predictions (ADR 0006) all
exist so the child learns "apple is here" as muscle memory. A surface that
silently reshuffles itself betrays that, and greedy raw-frequency promotion is
a positive-feedback loop (promote -> easier to reach -> tapped more -> stays
promoted) with no exploration term, which starves vocabulary breadth in a
language-learning tool. (Both points from the independent technical review.)

## Decision

1. **The rendered home strip shows ONLY pinned items.** Pins are
   parent-chosen and change only when the parent changes them, so the strip is
   motor-stable, like the rest of the app. It sits above the grid on the home
   board (depth 1) only; the 56-tile core map is never touched. Cap 6.

2. **Auto is a suggestion, not a moving surface.** "Both options" is satisfied
   by: auto *detects* candidates (most-tapped buttons) and offers them in the
   parental editor as "used a lot, pin it?"; the parent decides. Nothing
   auto-renders into the child's strip, so there is no self-reinforcing loop
   and no live reshuffle. The detection (`rankByFrequency` over the tap log) is
   computed **on demand in the editor**, never on the home hot path.

3. **A `ButtonRef` is `{boardId, buttonId}`**, resolved to a live `AACButton`
   via `editableBoards` (so a promoted custom button works too). Folders are
   never promoted; a ref that no longer resolves is dropped.

4. **Strip hidden when there are no pins.** Default (no pins yet) = no strip =
   no extra chrome, which also keeps the home screen from over-stacking on a
   phone (sentence bar + grid only until the parent opts in).

5. **Pins persist backup-excluded**, in the app support directory alongside
   custom buttons (ADR 0012), NOT shared_preferences. This makes all
   parent-authored board customization share ONE backup posture (excluded per
   ADR 0002) instead of three different ones, and avoids a pin (that rode
   backup) dangling against a custom button (that did not) after a restore.
   Portability of all parent content is a single deliberate post-alpha item.

6. **Tapping a favourite is a normal communication act:** it speaks and appends
   to the sentence bar (ADR 0010) and feeds the same `(stateKey, buttonId)`
   posterior as the button on its own board (ADR 0009 keying, no double count).

## Open clinical confirm (for clinical review)

This ships suggest-and-pin (stable strip). If she wants the strip's auto half
to populate itself live, that is available but trades motor stability and
vocabulary breadth for zero-touch convenience; if chosen, freeze slot order
once populated rather than re-ranking on every tap. Named for her decision; not
blocking alpha.

## Consequences

- Stable, motor-safe home surface; no entrenchment loop; minimal chrome.
- Auto detection runs only when the parent opens the editor (off hot path).
- Authored by the implementer; revised after the independent technical
  review (which flagged the motor-planning and feedback-loop tensions).
