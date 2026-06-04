# ADR 0020: Guided onboarding tour + first-use tips

Status: Accepted (2026-06-03). Implements the v6 handoff, then reworked per the
v7 handoff (see Amendment 1). Adds two things only; nothing else changed.

## Amendment 1 (v7, 2026-06-03): tour scoped to Home; tips do the rest

The v6 tour ran 11 steps over the Home board while six of them described
controls on other screens (editor, gate, voice). The fix:

- **The tour is now 5 spotlight steps, ALL on the Home board:** the board, the
  sentence bar & speak, the next-word glow, a folder, the settings gear. Live
  "N of 5"; Back / Next / Skip; ends on Finish. It never navigates to another
  screen and never describes a control that is not on the current screen. The
  six off-Home steps were removed (their l10n keys deleted).
- **Everything deeper is taught by contextual first-use tips, not the tour.**
  Tips now carry a title + body and are wired on FIVE screens, each anchored to
  the real control there: board editor (Select), math gate (the equation),
  custom buttons (the add control), home favourites (the "Pinned now" label),
  advanced settings (the first section label).
- **One tip at a time, cleared on navigation:** a single shared
  `FirstUseTipController` holds one OverlayEntry; a new show replaces the prior,
  and each host clears it in `dispose`. Anchored via the target's GLOBAL rect
  through the root Overlay, so it floats correctly above dialogs (the gate) too,
  and auto-flips above/below the anchor.
- **Visibility:** the bubble is fully OPAQUE at rest; only the slide-in
  (translateY, reduced-motion-gated) animates. Visibility is never gated on an
  opacity animation, so the tip is readable even if the entrance does not play.

Decisions 1-6 below are the original v6 design; where they conflict with this
amendment (step count, centred-card steps), the amendment governs.

## Context

Parents had no walkthrough of the app's controls (board, sentence bar, glow,
folders, the gated settings, and the round-1/round-2 editor features). The v6
handoff adds a parent-facing coach-mark tour and one-time contextual tips.

## Decisions

1. **Coach-mark tour, not a slideshow.** A full-screen dim layer with a rounded
   spotlight cutout over the target, plus a caption card (title, body, "N of
   11" progress, Skip / Back / Next). Implemented as a custom overlay
   (`lib/ui/tour/`), driven by an 11-step list, rather than a package, mirroring
   the prototype's own engine. The overlay sits ABOVE the board Scaffold so the
   dim covers the app bar too.

2. **Eleven steps, in order:** board, sentence bar & speak, next-word glow,
   folders, settings gear (and why it is gated), math gate, drag-to-rearrange,
   multi-select, record-your-voice, add custom buttons, favourites.

3. **Real spotlights where reliable; centred cards otherwise.** The five
   board-resident steps spotlight the real widgets via GlobalKeys
   (`tourBoardKey`, `tourSentenceKey`, `tourSettingsKey`). The six steps whose
   controls live on gated/pushed screens (gate, editor drag, multi-select,
   record voice, add buttons, favourites) render a centred caption card with no
   spotlight (`TourTarget.none`). This is the prototype engine's OWN documented
   behaviour when a target is not on the current screen, and it avoids fragile
   live cross-screen navigation + sheet-driving during an overlay. (A future
   enhancement could push those screens and spotlight their controls live.)

4. **Two entry points.** End of first run: the last onboarding screen offers
   "Take the quick tour" (sets `tourPendingStartProvider`, completes onboarding;
   the board starts the tour on mount) vs "Skip, go to the board". And a "Take
   the tour" row in Settings re-runs it any time (pops to the board, then
   starts).

5. **Skippable anywhere; no gamification.** No streaks, no completion bar, no
   persisted "progress". Skip / Finish simply stops. The tour is never shown on
   the child surface (it only runs when the parent starts it).

6. **First-use tips.** A one-time dismissible bubble the first time a parent
   opens a powerful screen, wired on the board editor ("Press and drag, or tap
   Select ..."). The per-tip "seen" flag is a single SharedPreferences bool
   (`FirstUseTipsStore`), so it shows once then never again. Suppressed while
   the tour is active.

## Consequences

- Three GlobalKeys are attached to existing board widgets via `KeyedSubtree`
  (no behaviour change). The board screen now returns `Stack[Scaffold, overlay]`.
- No new third-party dependency. The tour state is a `StateNotifier`; the tip
  flag reuses the existing SharedPreferences pattern.
- l10n: all tour/tip strings localized in en/es/ar; step bodies de-dashed for
  the house no-em-dash rule.
