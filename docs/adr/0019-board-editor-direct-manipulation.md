# ADR 0019: Board editor redesign (direct manipulation), hide/show, custom voice, replace picture

Status: Accepted (2026-06-02). Implements the UX designer's v5 handoff
("Board Editor redesign only"). Supersedes the interaction model of ADR 0014
(tap -> menu -> "Move" -> tap destination) while keeping every product decision
ADR 0014 locked (folders move-locked, position-only overlay, favourites as
cross-board refs, child never sees a moving layout).

## Context

ADR 0014 shipped a semantic tap-to-move editor. The v5 handoff replaces it with
a direct-manipulation editor and adds two genuinely new parent features. Scope
is the editor screen ONLY; the child board, sentence bar, onboarding, settings,
math gate, feedback, and phone/RTL layouts are unchanged.

## Decisions

1. **Arrange (default) = drag to rearrange.** Tiles jiggle (reduced-motion
   gated); long-press + drag reorders. A drop onto another word does an
   INSERTION reorder among the board's non-folder slots (words shift, folders
   stay); a drop onto an empty slot moves it there; a drop onto a folder is a
   no-op. A plain tap opens a quick-action sheet. This replaces the ADR 0014
   tap/Move/destination flow. Reorder commits through the existing position
   overlay (`BoardLayout`, ADR 0014) via a new batch `setPositions`.

2. **Folders stay move-locked (ADR 0014).** Subcategory folders are not
   draggable, not a drop target, and not selectable; they show a lock chip and
   remain doorways (tap navigates into the sub-board on the editor's own nav
   stack, never the child stack).

3. **Select mode = batch actions.** An app-bar "Select" toggle puts every
   non-folder tile into a checkable state with a live "N selected" count and
   All/None. A bottom batch bar applies, to all chosen tiles at once: Pin /
   Unpin (smart: Unpin if all are already pinned, respecting the favourites
   cap) and Hide / Show (smart flip: Hide if any are visible, else Show).

4. **NEW - Hide / Show tiles.** A hide-only overlay (`HiddenTiles`,
   `hidden_tiles.json`) keyed by (boardId, buttonId). Applied on the CHILD path
   (`activeBoardProvider`) AFTER the layout overlay: a hidden button leaves the
   board so its slot renders empty, while every other tile keeps its exact
   position (muscle memory, ADR 0006). The editor does NOT apply the filter, so
   a parent still sees hidden tiles (greyed, eye-off badge) to un-hide them.
   Hiding never touches a button's id/category, so bandit + glow are untouched.

5. **NEW - Custom voice per tile.** A parent (behind the math gate) records a
   short clip with the microphone; it plays INSTEAD of TTS for that tile. Stored
   on-device only: `custom_voices.json` (buttonId -> filename) + clips in a
   `custom_voices/` subdir, the same backup-excluded location as the rest of the
   parent-authored data. At speak time `_speakSafely` prefers the clip (stopping
   any in-flight TTS first); a missing/broken clip falls back to the built-in
   voice so a non-speaking child is never silenced (ADR 0004). Recording uses
   the `record` package (AAC, capped at 15s); playback reuses `just_audio`.
   - **Permissions:** adds `NSMicrophoneUsageDescription` (iOS) and
     `RECORD_AUDIO` (Android). These are the FIRST microphone permissions in the
     app; they are requested at record time, only reachable behind the gate.
   - **Privacy (already disclosed on kinderhorizon.org/lighthouse/privacy):** a
     recording stays on the device, is never transmitted, and is never placed in
     a crash report or feedback payload. The device's own backup (iCloud /
     Google) may include it; that copy is the parent's, not ours. Store and App
     Privacy / Data Safety declarations must add microphone before submitting.

6. **"Replace picture" = per-tile icon override.** An override store
   (`icon_overrides.json` + `icon_overrides/` subdir) keyed by (boardId,
   buttonId); applied on BOTH the child and editor paths via
   `AACButton.withIconUri` (preserves id/category, so bandit + glow are
   untouched, ADR 0017). Uses the system photo picker (PHPicker / Android photo
   picker), so it adds no Photos permission or usage string (ADR 0016). Reuses
   the custom-button image size/type caps.

7. **Badges:** amber star (favourite), brown mic (custom voice), grey eye-off
   (hidden). Batch and single actions confirm with a toast (SnackBar).

8. **Preserved from before:** the share-board action (ADR 0015), per-board /
   all-board reset (overflow menu; positions only, matching the existing copy),
   tap-an-empty-slot to add a custom button (ADR 0012/0014), and RTL correctness
   (the grid stays a `GridView`, so logical positions mirror without
   special-casing).

## Composition order (read paths)

- Child (`activeBoardProvider`): bundled -> custom buttons -> layout (positions)
  -> icon overrides (art) -> hidden (drop). Hidden is last and child-only.
- Editor (`editableBoardsProvider`): bundled -> custom -> layout -> icon
  overrides. NO hidden filter (the editor must show hidden tiles to un-hide).

## Consequences

- Three new backup-excluded JSON overlays join the existing pattern; a corrupt
  one degrades to "no customization" and never blocks the board.
- The microphone permission is a new store-review surface; handle the Data
  Safety / App Privacy declarations before the next submission.
- Sentence-bar replay still uses bundled/system TTS; custom voice plays on the
  per-tile tap (the explicit requirement). Replaying a whole sentence in the
  parent's recorded voice is a possible future enhancement.
