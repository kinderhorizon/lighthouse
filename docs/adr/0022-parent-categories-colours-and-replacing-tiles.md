# ADR 0022: Parent-made categories, tile colours, replacing a tile on a full page, start blank

Status: Proposed (2026-10-26). Built; awaiting clinical review (on-device test
by the clinical lead, Maryam, on iPad and iPhone) before Accepted.

Amends: ADR 0012 (custom buttons), ADR 0014 (layout overlay: folder rule),
ADR 0019 (board editor). Relates to: ADR 0006 (tiles never move), ADR 0013
(favourites), ADR 0015 (pack sharing).

## Context

Parent feedback after launch asked for four things:

1. Change the background colour of a button they made, "to match the other
   tiles in that category". Every parent-made button is grey today: its
   category is `custom`, which no board colours.
2. Make their own categories.
3. Start from a blank template.
4. "Make the category (Colours)": read with the founder as the same as 1 and 2
   (a parent's categories and buttons carry colours), NOT a vocabulary page of
   colour words.

Two facts shape the design. Home is completely full (56 of 56 slots), and a
parent could only add a button in an EMPTY slot, so nothing parent-made could
ever go on Home. And the core promise (ADR 0006) is that tiles never move.

## Decision

### 1. Tile colour (amends ADR 0012)

A parent-made button (word or category folder) may carry `tile_color`, one of
the SIX Fitzgerald fills the bundled boards already use (`TileColor` in
`lib/models/tile_color.dart`), or none (grey). No free colour picker: the
colour tells the child what kind of word a tile is, and an arbitrary colour
would break that code and could make an unreadable dark tile.

- Display only. The button's `category` stays `custom`, so glow, learning,
  sentence rules, the editor's "is this mine" check and pack export behave
  exactly as before. Every tile surface resolves the fill through
  `resolveButtonColor` (grid, editor, favourites strip, favourites screen).
- A new button starts in its page's colour: the category's colour on a
  parent-made page, the single group colour of a bundled sub-board (Food,
  People, ...), grey on Home (which mixes colours). The parent can change it
  when adding, and later from the tile's sheet ("Change colour").
- Stored in `custom_buttons.json` and carried in a shared pack (`tile_color`
  on the button). Parsing keeps only the six palette values; anything else
  (unknown, crafted) falls back to the category colour instead of failing the
  board.

### 2. Parent-made categories

A category is a FOLDER tile the parent makes (name, optional photo, colour)
that opens a new BLANK page, which the parent fills with their own buttons.

- Stored as a custom button with `link_id` = the page id. Page ids are
  `cat_<n>` from a persisted, never-reused counter, so a deleted page's
  settings can never leak into a new one.
- The page itself is generated, not stored: `categoryBoardFor` builds an empty
  6 x 8 board (the bundled sub-board size) named after the folder. Its words
  are ordinary custom buttons on that page id. The child's folder tap and the
  editor resolve it alongside registry boards.
- Categories can nest (a category on a category page).
- Deleting a category deletes everything that only existed because of it, in
  one step: its folder, every button on its page and on any category nested
  inside, and for all of those their recorded voices, favourites pins, and the
  pages' hidden, arrangement and picture settings. The parent is asked to
  confirm (with the count) first. "Reset this board" cascades the same way.

### 3. Replacing a word (for a full page)

The parent always chooses where a new button or category goes (the founder's
rule: ask the parent, never decide for them). "+ Add" asks "where should it
go?": an empty square, or a built-in word to put it in place of. On a full page
(Home is full) only the second is possible. A built-in word's sheet also offers
"Put your own button here".

The replaced word is SET ASIDE, not deleted: it disappears from the child's
board and the editor, its learning is kept, and deleting the new button brings
it back, into the slot the new button was in at that moment (so nothing else
jumps, even if the parent has since moved things around).

- Stored as `replaces_id` on the custom button. `applyCustomButtons` places a
  replacing button in the replaced word's slot (the one deliberate exception to
  "never evict", P0-1), before the layout overlay, so the new button is an
  ordinary tile afterwards: it can be dragged, hidden, pinned, edited.
- Created on a rearranged board, it also gets a layout override to the word's
  DISPLAYED slot, so it appears exactly where the parent tapped.
- On delete, the word gets a layout override to the new button's current
  displayed slot, then the button is removed: the word returns to that slot.
- Only built-in WORDS can be replaced. Never a folder (a folder can be the only
  way into a page) and never a parent-made button (edit or delete it instead).
- If a content update removes the replaced word, the button is placed like any
  other custom button (its stored slot, else the first free one).

### 3b. Editing your own tiles

Tapping a parent-made tile in the editor offers "Edit": word (or category
name), photo and colour in one dialog, the same dialog used to add. Renaming
keeps the button's id, so its learning, pins and recorded voice stay with it.
A parent-made tile, word or category, moves like any word (long-press, drag).
Built-in folders stay locked (ADR 0014).

### 4. Start blank

"Start this page blank" (editor menu) hides every word on the page in one step
after a confirm. Folders stay, so no page becomes unreachable. Hidden words
keep their slots (ADR 0019, including the phone reflow fix), and tapping a
hidden word in the editor offers "Put a new button here" (section 3), so a
parent can fill a blank page with their own words in any slot.

### Composition order (unchanged)

bundled -> custom buttons (free slots, and replacements) -> layout (positions)
-> picture overrides. The child view then drops hidden tiles. The editor uses
the same order without the hidden filter.

### Layout rule change (amends ADR 0014)

Built-in folders still ignore layout overrides, cannot be dragged, and always
claim their own slot. A parent-made category folder is treated like a word: it
honours its override and can be dragged, since moving it never cuts off a page.

## Consequences

- Parents can now add to Home, and every board, without anything they did not
  choose moving.
- `custom_buttons.json` gains three optional fields (`tile_color`,
  `replaces_id`, `link_id`). Old files load unchanged (no colour, no
  replacement, words only). The id counters gain a `_categories` entry.
- A pack shared from a page with a parent-made category drops that folder, as
  for every folder in a v1 pack (ADR 0015). Sharing the category page itself
  shares its words.
- Parent-made words use system TTS or the parent's recorded voice, as before.
  No new built-in words, so no new bundled audio.
- Deleting a single parent-made button now also deletes its recorded voice and
  favourites pin (previously both were left behind).

## Reviewers

- Clinical lead (Maryam, BCBA): pending, on-device on iPad and iPhone.
