# ADR 0023: Copying a setup to another device, and deleting a shared board

Status: Proposed (2026-11-08). Built; awaiting clinical review (on-device test
by the clinical lead, Maryam) before Accepted.

Amends: ADR 0015 (pack sharing: the folder notice, shared board ids, deleting
a shared board). Relates to: ADR 0002 (no automatic telemetry, backup
exclusion), ADR 0012 / 0014 / 0022 (never-reused ids), ADR 0013 (pins),
ADR 0019 (hidden tiles, pictures, recordings).

## Context

A parent wrote back after the ADR 0015 amendment: "when it transfers the file
it's only sending the basic board and none of the custom words we add ... It
lists several Home Core files from the downloads but they're all copies of
the basic board." Their screenshot showed five "Home Core" boards in the
pinned-words group list.

What they hit:

1. A shared pack is ONE page, and folders are dropped from it (ADR 0015,
   Decision 1). Sharing Home sent Home's words, without Food, People and the
   rest, and without any word the parent had added inside them. Nothing said
   so, so it looked as if the custom words were lost.
2. What the parent wanted was to move the child's setup to another device.
   No path did that: every parent-made file lives in Application Support,
   which is deliberately kept out of the device's own backup (ADR 0002), so a
   new device always starts blank.
3. Each import of the same file is a new, separate board (by design), and
   there was no way to delete one. The five copies stayed.

## Decision

### 1. Copy to another device (new)

Settings gains an "Another device" section with two rows, both behind the
parental gate:

- **Copy to another device** writes ONE file, "Lighthouse setup.json" (named
  in the sender's language), and opens the share sheet with a short message
  that says how to open it. Before sharing, the dialog lists what goes and,
  when there are any, says that photos and voice recordings stay on this
  device.
- **Copy from another device** picks a file and REPLACES this device's setup
  with it, after a confirmation that says so and that it cannot be undone.
  The same file opened from Messages, Mail, Files, WhatsApp or Quick Share
  ("open with Lighthouse", ADR 0015 amendment) is offered the same way:
  confirm, then the math gate, then replace.

The file is plain `.json` with a top-level `lighthouse_setup` key (the format
version, now 1). A single shared board has no such key, so every path tells
the two apart: a setup picked in "Import a board pack" is offered as a setup,
and a single board picked in "Copy from another device" is added as a shared
board, rather than refused. A file from a newer format asks the parent to
update Lighthouse.

**What travels:** the parent's own words and categories (with colours, and
the built-in word each one replaced), where tiles are, hidden words, pinned
words, shared boards, and the app settings (language, voice mode, glow style,
touch help, return to Home, tile text / pictures).

**What does not:** photos (on parent-made buttons and pictures picked for
tiles), voice recordings, and the learned word weights and tap history. The
first two keep the published promise that they never leave the device; the
learning stays with the device it happened on, as for a shared board
("structure, not learning", ADR 0015).

### 2. Every id is fresh on the receiving device

Ids on a device are never reused (ADR 0014, ADR 0022): an old id can still
have learning, a recording, a picture, a pin or a hidden flag attached to it
on that device. The sender's ids mean nothing there. So on import:

- every parent-made word becomes `custom_<board>_<n>` from the receiving
  device's own high-water marks, every category page a fresh `cat_<n>`, and
  every shared board a fresh `imported_<n>` (its words `imported_<n>__...`);
- pins, arrangement, hidden words, the word a button replaced, and the links
  of category and shared-board folders are all pointed at the new ids;
- built-in boards and words keep their ids: they are the same words on every
  device;
- anything that refers to what the file does not bring (a board this device
  does not have, a shared board not in the file, a parent-made word id with
  no word) is left out, so it can never attach itself to something added
  here later.

### 3. Replace, in a safe order

Everything that can fail on a bad file is worked out in memory first; nothing
is written until it has. Then the new setup is written (new shared boards
first, then the buttons, arrangement, hidden words, pins and settings, each
file atomically), and only then is what the old setup leaves behind cleaned
up: the photos, recordings and pictures of the parent-made words that are now
gone, the old category pages' pictures, and the old shared boards. Recordings
and pictures on BUILT-IN words stay: they are the same words, and the file
cannot bring them. The learning on this device stays. The child's view goes
back to Home.

An unreadable custom button store is never overwritten (as for every other
write to it, item 7).

### 4. The file is untrusted

Anyone can hand a parent a file. Each part is checked and what cannot be used
is dropped, not trusted: ids must be safe (the shared-board rule: no path
separators, `..`, NUL, `|` or `:`), board ids must be slugs, slots must be in
range, icons must be bundled assets, photo paths are cleared, unknown
settings values are ignored, and tile text and pictures are never both
hidden. The file is capped at 4 MB, the same cap as a shared board and the
native "open with" copy. A shared board in the file may not take a built-in
or category page id.

### 5. Sharing one board says what it leaves out

When the page being shared has folders, the share dialog now says: "Folders
on this page (like Food or People) are not included. To copy everything, use
Settings, Copy to another device." (both the editor and Settings).

### 6. Deleting a shared board

Settings, Shared boards gains Delete on each board, after a confirmation.
Deleting removes every tile that opens it (a word such a tile replaced comes
back into its slot), everything the parent added on it, its pins, hidden
words, arrangement, pictures and recordings, and the board file.

Shared board ids now come from a persisted high-water mark
(`imported_boards/next_id`, inside the backup-excluded import directory),
like the other ids: counting the boards present would hand a deleted board's
id, and whatever is still attached to it, to the next board. Boards added
before the mark existed are counted, so the first new id is above them.

## Consequences

- A parent can move a child's setup to a new or second device in two steps,
  and remove extra copies of a shared board.
- New data path out of the device, by the parent's choice only: the setup
  file. `docs/privacy/app-data-inventory.md` section B5 records exactly what
  is in it; the hosted privacy page needs the same section before release.
- Photos and recordings have to be added again on the new device. Carrying
  them would change a published privacy promise; it is left for a separate
  decision.
- A setup made by this version opens in later versions. Older versions see an
  unknown file: "That file is not a Lighthouse board".
- The id remap is pure (`prepareForDevice`) and covered by unit tests; the
  whole copy is covered end to end on real stores in two temp folders.

## Testing

- `test/services/device_setup_test.dart`: the file's key contract (no photo
  paths, no learning), reading back, newer format refused, untrusted parts
  dropped, fresh ids from the receiving device's marks, references following
  the new ids, dangling references dropped.
- `test/services/device_setup_service_test.dart`: two devices on real stores;
  what arrives, what is replaced, what is cleaned up, what stays (built-in
  recordings and pictures), the old shared board deleted and its id never
  reused; an unreadable store is not overwritten.
- `test/services/board_registry_test.dart`: shared board ids are never reused,
  across restarts too.
- `test/state/parent_tiles_provider_test.dart`,
  `test/ui/settings/shared_boards_screen_test.dart`: deleting a shared board.
- `test/ui/incoming_board_file_handler_test.dart`,
  `test/ui/settings/device_setup_send_test.dart`,
  `test/ui/edit/board_edit_screen_test.dart`: the dialogs, the gate, the share
  sheet, the folder notice, and that no file lingers.

## Reviewers

- Clinical lead (Maryam, BCBA): pending, on-device.
