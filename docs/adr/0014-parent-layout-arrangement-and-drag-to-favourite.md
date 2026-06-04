# ADR 0014: Parent layout arrangement and drag-to-favourite

Status: Accepted (2026-05-30, after a re-review sign-off; build-time notes from
the re-review are folded into Decisions 5 and 9). **Amendment 1 (sub-board reach)
is ACCEPTED below (independent sign-off 2026-05-30) and built.**

## Context

Clinical-lead alpha feedback (round 3, the "added feature" + the earlier #5
"adding buttons and favourites is not very user friendly"): a parent should be
able to

1. **arrange the tiles** on a board into the order that suits their child, and
2. **pin a favourite by dragging** a tile up to the home favourites bar, and
3. reach the **create-button** and **favourites** affordances from an obvious
   place (icons beside the Settings gear, or a small menu), instead of the
   current dialog-driven flow.

This collides, on its face, with the app's deepest invariant: **buttons never
move**. Fixed grid positions, board-exclusive ids (ADR 0009), and
glow-not-move predictions (ADR 0006) all exist so the child learns "apple is
here" as motor memory; a surface that reshuffles itself is "a regression worse
than no glow" (ADR 0006). ADR 0013 already resolved the same tension for
favourites: a parent-controlled surface that changes ONLY when the parent
changes it is motor-stable, because from the child's point of view it is fixed.

The current custom-button flow (ADR 0012) also drops a new button into "the
first empty slot" with no visual placement, which is exactly the unfriendliness
#5 names. A visual, in-context arrangement mode subsumes that.

## Decision (proposed)

1. **Parent edit mode, behind the math gate, never child-reachable.** Arrange
   is a distinct, visually-obvious mode entered from a board toolbar affordance
   (an Edit/arrange icon next to the Settings gear, or an overflow menu holding
   Arrange / Add button / Favourites), gated by the same math gate as Settings
   and the existing editors (ADR 0012/0003). In edit mode the grid shows a clear
   "editing" treatment (e.g. drag handles / a tinted scrim) so it is never
   confused with the child's normal board, and normal tap-to-speak is suspended.
   The child, outside the gate, can never enter edit mode or move a tile.

2. **The child NEVER sees a moving layout (non-negotiable).** Rearrangement
   applies only inside the gated edit mode and is then fixed. The default (no
   overrides) is the bundled, motor-planned layout, unchanged. This preserves
   ADR 0006/0009: positions are stable for the child; only a deliberate parent
   action behind the gate alters them, exactly like ADR 0013 pins.

3. **Drag-to-reorder within a board** is a SWAP of grid slots (not an
   insert-and-shift), because the grid is a fixed sparse coordinate space and a
   swap keeps every other tile's position untouched, minimizing motor churn.
   Long-press to pick up a tile in edit mode, drop on another slot to swap;
   dropping on an empty slot moves it there. Cross-board moves are out of scope
   for v1.

4. **Drag-to-favourite** reuses ADR 0013 pins: the home favourites bar is a drop
   target in edit mode; dropping a tile on it pins that `{boardId, buttonId}`
   (cap 6 unchanged). No new favourites concept, just a second way to create the
   same pin the editor already creates.

5. **Layout is an OVERLAY, not an edit of bundled JSON** (same posture as ADR
   0012 custom buttons and ADR 0013 pins). Bundled board JSON stays read-only.
   A `BoardLayout` persists per-board position overrides keyed by **buttonId ->
   Position**, applied as a pure merge at read time. Composition order in
   `activeBoardProvider`: bundled board -> `applyCustomButtons` (ADR 0012) ->
   `applyLayout` (this ADR) -> favourites are a separate surface. Because the
   overlay only ever changes a button's POSITION (never its `id` or `category`),
   it cannot scramble learning or glow (see 6).

   **Apply-time robustness (mirrors ADR 0013's "a ref that no longer resolves is
   dropped").** `applyLayout` is defensive, because a layout file outlives the
   bundled content it references: (a) an override whose `buttonId` is no longer
   present on the (possibly updated) bundled board is dropped; (b) when an
   override and a non-overridden button contend for the same slot (a future
   `core_main.json` added a button where the parent had moved another), the
   resolve places overridden ids first, so the parent's override WINS the slot
   and the displaced button falls to its own bundled slot if free, else the
   lowest free slot (the two-phase resolve below); either way the result stays a
   valid permutation, never an overlap, so a content update can never scramble
   the board into two-on-a-slot. Folders are the one exception: they are pinned
   to their bundled slot and placed before any override (Amendment 1), so a stray
   override can never displace a subcategory. (c) a corrupt or partially-written
   layout file is ignored in full and the board falls back to the bundled layout,
   exactly as `CustomButtonStore` and `FavouritesStore` already do. A bad overlay
   must never block the board: that rule is load-bearing here too.

   **`applyLayout` is a total function that guarantees the one-button-per-slot
   permutation invariant (the model the Decision 6 guard enforces).** Decision 3
   describes the edit-mode *gestures* as a swap (two occupied) or a move (onto an
   empty slot); both transform a valid assignment into another valid assignment,
   so the SAVED overlay (`buttonId -> Position` deltas vs bundled) is always a
   valid injective map for the button set it was authored against. The only thing
   that can break that injectivity is a later bundled-content update, so the
   resolve is defined as a deterministic two-phase pass rather than naive
   independent drops: (1) keep only overrides whose `buttonId` still resolves;
   (2) place buttons in a stable order (overridden ids first, then by bundled
   row-major slot, then by id), each taking its desired slot if free, else its
   bundled slot if free, else the lowest-index free slot; (3) assert the result
   is injective. In the no-skew case this reproduces the parent's arrangement
   exactly; under skew it degrades deterministically and never overlaps, instead
   of dropping one side of a swap and leaving two buttons on one slot (which
   would only surface as a guard-test failure, too late).

   **The layout overlay is the SOLE source of position deltas.** A custom
   button's `row`/`col` in `custom_buttons.json` stays its creation/default slot
   and is never rewritten by a move; only `board_layout.json` records the delta.
   This keeps the two overlays from desyncing or double-applying, and as a free
   side effect "reset layout" reverts a moved custom button to its creation slot.

6. **Bandit identity and glow are position-independent, so moving a tile is
   safe.** The bandit keys on `(stateKey, buttonId)` with no position component
   (ADR 0009), and the glow highlights by id, not slot. A repositioned button
   keeps its posteriors and its glow. The layout overlay MUST preserve id and
   category; a guard test asserts the overlay is a position permutation only (no
   id/category mutation, no two buttons sharing a slot).

7. **Persistence: one more backup-excluded JSON** in the app support directory
   alongside `custom_buttons.json` and the pins (ADR 0013), NOT
   shared_preferences and NOT Isar (no schema bump, ADR 0005). This keeps ALL
   parent-authored board customization (custom buttons, pins, layout) on one
   backup posture (excluded per ADR 0002), so a restore can never leave one kind
   dangling against another. Portability of all parent content stays a single
   deliberate post-alpha item (carried from ADR 0012/0013).

8. **Add-button gets a visual slot (closes #5).** With an in-context edit mode,
   the custom-button add flow (ADR 0012) stops using "first empty slot" and
   instead lets the parent place the new button into a chosen empty slot in edit
   mode. The dialog still captures word + photo; placement becomes a drag/drop.

9. **Custom-button identity becomes slot-independent (amends ADR 0012).** ADR
   0012 derives a custom button's id from its slot
   (`custom_{boardId}_{row}_{col}`, `custom_button.dart`). That is incompatible
   with a position overlay: moving such a button forces a choice between two bad
   outcomes. Keep the id and the freed original slot invites a new custom button
   whose derived id collides with the moved one, breaking the globally-unique-id
   invariant that ADR 0009's board-scoped bandit learning rests on. Re-derive the
   id from the new slot and the button's learned posteriors (keyed on the old id)
   are silently orphaned. Resolution: a custom button is assigned a stable id at
   creation that does NOT encode position (a per-board monotonic counter
   persisted in `custom_buttons.json`, e.g. `custom_{boardId}_{n}`), and
   `row`/`col` become pure position that the layout overlay may change freely.
   Legacy entries that have no stored id keep their existing slot-derived id once
   (read, assign, persist on first load) so no alpha-device posteriors are
   orphaned. With this, moving a custom button is just a position change: no id
   collision, no lost learning. Rejected for v1: excluding custom buttons from
   layout-move (the escape hatch). The identity fix is small, removes the
   collision class entirely, and is wanted regardless. This change is recorded
   here and lands with the implementation; ADR 0012's Decision 1 is amended
   accordingly.

   **The counter MUST be a persisted monotonic high-water mark, never recomputed
   from the live entries.** Store `{boardId -> nextN}` in `custom_buttons.json`
   and only ever increment it. If next-n were instead derived from
   `max(existing n) + 1`, deleting the highest-numbered custom button and then
   adding another would reuse that id, and the new button would silently inherit
   the deleted one's bandit posteriors (which ADR 0012 never purges on delete).
   This is the one place Decision 9 can regress if built naively.

   **Bonus (independent of layout): this also fixes a latent ADR 0013 x ADR 0012
   stale-pin bug.** Pins key on `(boardId, buttonId)` and resolve against the
   live index. With slot-derived ids, pinning a custom button, deleting it, then
   adding a different button in the same slot silently resurrects the stale pin
   onto the wrong button (the derived id is identical). Stable, never-reused ids
   make the stale pin fail to resolve and get dropped, which is correct. This is
   also why the escape hatch would have been insufficient: the bug exists with or
   without layout-move.

## Alternatives considered

- **Edit the bundled board JSON in place.** Rejected: assets are read-only, it
  breaks bundled-content updates, and it abandons the overlay pattern ADR 0012
  established.
- **Auto-arrange by tap frequency.** Rejected for the same reason ADR 0013
  rejected a live-reshuffling favourites strip: it violates motor planning and
  creates an entrenchment loop.
- **A separate full-screen "arrange editor"** instead of in-context edit mode.
  Rejected for #5: the whole complaint is that arranging is divorced from the
  real board; editing the board you are looking at is the friendlier model.
- **Insert-and-shift reorder** (like a list). Rejected: shifting cascades every
  downstream tile's position, the opposite of "minimize motor churn"; swap moves
  exactly two tiles.

## Decisions from the first review (2026-05-30)

These were the open questions; the first independent technical review
decided them and they are now binding on the build.

- **Edit-mode entry point: ONE gated "Edit board" affordance, not a row of
  toolbar icons.** Keep the child-facing AppBar calm (ADR 0003). Add-button and
  Favourites are reached from inside edit mode (that is where you add and pin
  anyway), not duplicated into a new toolbar menu. A single Edit/arrange entry
  (icon next to Settings, or a Settings entry) suffices.
- **Accessibility: the non-drag "Move to..." path is a v1 REQUIREMENT, not a
  fallback.** This is an accessibility org and the parent operating the editor
  may use switch access or VoiceOver; a drag-only parent tool would be
  off-mission. The semantic "move to slot" / "pin to favourites" action is the
  floor; drag-and-drop is the enhancement layered on top of it.
- **Empty slots / gaps: deliberate gaps are allowed** (real clinical value:
  reduce clutter for a particular child). `board_integrity_test`'s
  contiguous-row-major packing rule is a bundled-authoring constraint, not a
  runtime one; `AACGrid` already renders sparse boards, so an overlay that
  leaves a slot empty is fine.
- **Reset: required, at two levels.** A per-board "reset to default layout" in
  edit mode, plus a global "reset all customizations." A parent who mis-arranges
  must have a one-tap escape.
- **Scope of move: within-board + to-favourites only for v1, and this is an
  invariant, not just scope-trimming.** Cross-board or into-folder moves would
  put a button on two boards (or change its board), breaking ADR 0009's "each id
  lives on exactly one board, so learning is board-scoped." Out of scope by
  design, not by deferral.
- **RTL: a build requirement.** The swap animation and the drop-target math must
  mirror under `Directionality.rtl`; covered by a widget test on an Arabic
  locale, like the existing RTL tests.
- **Clip/color invariants hold (low risk) but are re-confirmed in CI.** Layout
  moves a button, it does not add one, so "every board word has a clip" and
  "every favouritable category has a color" (board_integrity_test) are not put
  at risk; the existing guards are re-run against a moved layout to prove it.

## Consequences

- Parents get in-context arrangement, a visual placement slot for new buttons
  (closing #5), and drag-to-pin favourites, without ever exposing a moving
  layout to the child.
- Motor planning, bandit identity, and glow are all preserved because the
  overlay changes position only and is gated + stable.
- One more backup-excluded JSON; the post-alpha portability/export item (ADR
  0012/0013) now also covers layout.
- New surface area: drag-and-drop UX, edit-mode discoverability, and the
  accessibility fallback are the main implementation risks and the focus of the
  open questions above.
- Status is Accepted: authored by the implementer, revised on 2026-05-30 to fold
  in the first independent technical review (blocking custom-button identity
  resolved as Decision 9, apply-time robustness added to Decision 5, open
  questions decided), then signed off on a re-review the same day with two
  build-time notes now folded in (the persisted high-water-mark counter in
  Decision 9, and the total-function `applyLayout` resolve in Decision 5). Build
  proceeds; the implementation commit goes back to the reviewer for build QA
  (counter no-reuse on delete-then-add, and the permutation guard under a content
  update and RTL).

## Amendment 1: sub-board reach (favourites from subcategories), PROPOSED (2026-05-30)

### Context

Clinical-lead feedback after testing the shipped arrange feature (`f7b5a61`):

1. Parents should NOT be able to move the subcategory (folder) tiles. (Shipped
   already as a fix: folders are locked in arrange mode.)
2. Parents should be able to arrange items that live ON a subcategory, and to
   surface a frequently-used subcategory word onto the home screen. The proposed
   mechanism was to MOVE an item from a subcategory to home, and if home is full,
   bump the displaced item back into its subcategory. A noted snag: short
   phrases have no subcategory to be bumped into ("maybe make one?").

The move-to-home idea is the wrong shape, and the phrase snag is a symptom of
that. Relocating a button to a different board breaks the invariant the base ADR
(Decision 5/6, and the reviewer's #5) and ADR 0009 rest on: **each button lives
on exactly one board, and the bandit scopes learning by that board.** Moving a
food word to home would bleed its food-context learning into home, or dual-home
the id (the globally-unique-id guard fails). Cross-board move stays out.

The goal (one-tap-from-home for a chosen subcategory word) is already served by
**favourites (ADR 0013)**, which the move model was reinventing: a favourite is a
reference, so pinning a sub-board word puts it one tap away on home WITHOUT moving
the button (it keeps its learning), WITHOUT consuming a home grid slot (the
favourites strip is a separate row, so "what gets displaced / where does it go"
never arises), and it works for phrases too (so no phrases-subcategory is
needed). The real gap is only REACHABILITY: arrange mode today acts on the
current board, and folders are locked, so there is no way INTO a sub-board to pin
or rearrange its items.

### Decision (proposed)

1. **No cross-board move (reaffirmed).** A button is never relocated to a
   different board. This preserves ADR 0009 board-scoped learning and the
   globally-unique-id guard. The clinical lead's move-with-swap-back is declined for this
   reason; the phrase snag dissolves because favourites need no subcategory.
2. **Folders are locked but become doorways.** Folder tiles stay fixed in
   position (Amendment to nothing; this is the shipped #1 behavior) AND, in
   arrange mode, tapping a folder NAVIGATES into its sub-board, still in arrange
   mode. The lock badge means "cannot move," not "cannot open." This is the only
   change to folder behavior.
3. **Favourites is the cross-board surface.** To bring a sub-board word to home,
   the parent pins it to home favourites from within that sub-board's arrange
   mode (the existing "Pin to favourites" tile action). Favourites already
   resolve across all boards (ADR 0013), so no new persistence and no new
   concept; the action simply becomes available on sub-boards, not only home.
4. **Within-sub-board arrangement.** Inside a sub-board in arrange mode, the
   parent can rearrange that board's items (same swap / move / add-at-slot /
   reset semantics as home) and pin any of them to favourites. Each sub-board's
   layout overrides are already keyed by boardId (Decision 5), so this needs no
   model change, only that the edit UI works on whatever board is on top of the
   stack rather than assuming home.
5. **The arrange session spans the board stack, gated throughout.** Navigating
   folders in arrange mode pushes/pops sub-boards on the same stack the child
   uses, but only behind the gate; the gate is entered once per arrange session,
   not re-prompted per folder. "Done" returns to the normal child view.

### Alternatives considered

- **Move-with-swap-back (the original idea).** Rejected: breaks ADR 0009
  board-scoping; the "phrases have no subcategory" problem is an artifact of the
  move model and disappears under favourites.
- **Empty home slots by default.** Unnecessary: favourites give one-tap-from-home
  without sacrificing core-vocabulary slots. A parent can still free a home slot
  by deleting/moving a tile and adding a custom button there (base ADR).
- **A favourites DROP target on sub-boards (drag a sub-board tile up to a home
  favourites bar).** Awkward across navigation (the bar is a home surface); the
  tap "Pin to favourites" action is the reliable, accessible path. Keep the
  drag-to-favourites drop-bar home-only; tap-Pin works everywhere.

### Open questions (for the review)

- Confirm tap-Pin-to-favourites on sub-boards is sufficient and the drag
  drop-bar staying home-only is acceptable (no drag-across-navigation).
- Confirm the gate is once-per-session, not per-folder, and that a child cannot
  reach sub-board arrange via folder navigation outside the gate.
- Any concern with the favourites cap (6) when pinning from multiple sub-boards
  (same cap + "favourites full" message as today; no change).
- RTL: navigation only, no new layout math; confirm no regression.

### Status

Amendment 1 is **Accepted** (independent technical sign-off, 2026-05-30) and
built. The reviewer's one binding requirement is honored: the arrange session
has its OWN navigation stack (`_BoardEditScreenState._stackIds`), so folder
"doorways" never mutate the child-facing `boardStackProvider`, and leaving
arrange mode (Done / system back) returns the child to exactly the board they
were on. The enable-Pin-on-any-board mechanism (the easy-to-miss one-liner) is
in place (`canFavourite = btn.type != folder`), with the favourites drop-bar
staying home-only. Folder-never-displaced is enforced in `applyLayout` itself
(folders pinned to their bundled slot, placed first), closing the
content-update-skew edge the reviewer noted. The base ADR 0014 remains Accepted
and shipped independently.
