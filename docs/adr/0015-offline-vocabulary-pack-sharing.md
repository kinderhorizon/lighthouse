# ADR 0015: Offline vocabulary-pack sharing

Status: Accepted (2026-05-31)

Revised 2026-05-31 after reviewer pass: resolved the import id-collision model
(Decision 1), locked the photo fork to text-only-with-notice (Decision 2), and
added the custom-words privacy note + temp-file cleanup (Decisions 3-4).
Reviewer signed off the id model 2026-05-31; folded in the Testing
ids-not-equal fix, the separate-board UX clarity, and the clip-keyed-on-text
note. Cleared to build.

## Context

The website describes families sharing the app between devices offline (over
Bluetooth / Wi-Fi Direct, "no internet at any step"). A website-claims audit
plus an independent reviewer pass confirmed: none of that is built (zero
Bluetooth / Wi-Fi-Direct / nearby-share / multipeer / p2p dependencies or code
in `pubspec.yaml` or `lib/`). The site copy was softened to future tense as an
interim fix.

The reviewer sharpened the claim into two genuinely different things:

- **Installing the app device-to-device.** On stock iOS this is essentially
  impossible (no Wi-Fi Direct; AirDrop/Multipeer cannot side-load a signed iOS
  app peer-to-peer without the App Store / TestFlight). It is realistically
  Android-only (APK hand-off over the OS share sheet) and store-dependent on
  iOS. Out of scope here; remains a future / Android-only item in the copy.
- **Sharing vocabulary/board packs offline.** Feasible cross-platform today and
  partly built: `BoardPackImporter` already imports a board file supplied
  through the in-app picker (Settings). A board pack is a data file, so "send my
  child's customized vocabulary to another family's tablet over the share sheet,
  no internet" is buildable and honest now.

Decision taken with the founder: build offline vocabulary-pack **sharing** now
(the missing export half on top of the existing importer) and split the website
copy accordingly.

## The export problem

A board pack, as the importer consumes it, is a single `AACBoard` serialized to
the v1.3 board JSON schema. Two facts complicate a faithful export:

1. **No serializer exists yet.** `AACBoard.fromJson` / `AACButton.fromJson`
   exist (the loader uses them), but there is no `toJson` on either. Export adds
   serialization that must be an exact inverse of `fromJson`, round-tripping the
   v1.3 schema (including `board_name_<locale>`, `colorKey`, button categories,
   pictogram/icon URIs, `voice_out`).
2. **Custom-button photos cannot travel in JSON.** A custom button
   (ADR 0012/0014) may carry an `image_path`: a photo the parent picked, copied
   into app-support storage and persisted as a bare filename. A JSON-only pack
   carries the filename but not the bytes, so a photo-backed button would import
   as a broken image on the recipient's device. Text and pictogram/ARASAAC
   buttons (whose icon is a bundled asset reference, not a device file) round-trip
   cleanly.

## Decision

1. **Export unit = one board, as the merged board; import re-ids it as a
   genuinely separate board.** Serialize the board the parent is viewing after
   `applyCustomButtons` + `applyLayout` into the v1.3 board JSON schema (add
   `AACBoard.toJson` / `AACButton.toJson` as exact inverses of `fromJson`).
   The naive "round-trips through the existing importer unchanged" does NOT
   hold: a merged board carries global ids (the bundled `board_id` like
   `core_main`/`board_food` and bundled button ids like `btn_want`), so
   importing onto a recipient who already has that board would overwrite or
   shadow their version and collide ids, violating ADR 0009's
   "each button id lives on exactly one board." So the importer changes (own
   it):
   - The importer assigns the incoming pack a **fresh, unique `board_id`** and
     **namespaces every button id** (and any intra-pack folder `link_id`) so it
     lands as a separate board, never overwriting a recipient board and never
     duplicating an id. ADR 0009's unique-id invariant is preserved.
   - Consequence by design: shared vocabulary transfers **structure, not
     learning**. The imported board starts cold (fresh bandit posteriors) on the
     recipient. This is correct: the sender's posteriors are not transferable
     and would be wrong for a different child anyway. State this plainly in the
     share UX.
   - **A shared pack imports as a NEW, separate board, not merged into the
     recipient's existing one.** Because we export the whole merged board and
     re-id it, a parent who shares `core_main` gives the recipient a standalone
     re-ided copy of the entire core vocabulary (cold) plus the sender's
     text-only customs: the recipient ends up with a second core board, not
     their friend's words layered onto their own. This is a defensible v1 choice
     (it matches the importer's "imported boards are separate" model and avoids
     overlay-merge complexity), but it is NOT the naive "add my friend's words to
     my board" expectation, so the ADR and the share/import UX must say so
     plainly. A "merge the delta onto my existing board" flow is a v2
     delta-export model, named here, not built now.
   - **Clip resolution stays keyed on text, not id.** Bundled neural clips
     resolve by `voice_out`/text hash (see `tighten_silence` dedup), so re-iding
     a shared bundled word does not break its audio: it resolves against the
     recipient's identical clip set and keeps its neural voice. `toJson` must
     preserve `voice_out` faithfully; it must never make clip lookup depend on
     the button id. (Custom buttons use system TTS, as today.)
   - **v1 scope (flag for reviewer):** export a single board. A folder button
     that links to another board (sub-board) is out of v1 scope, because a
     faithful transfer would need a multi-board pack and consistent link
     rewriting. v1 either excludes link/folder buttons from the export or ships
     them only when the pack is self-contained; multi-board packs are v2.

2. **Photo handling: text-only-with-notice (decided).** JSON-only pack; a
   custom button that references a device-local photo is exported **as a
   text/label-only tile** (drop the device `image_path`/icon so it renders as a
   labelled text button on the recipient, never a broken image). The export
   surfaces a plain-language count: "N buttons use photos from this tablet and
   will be shared as words only (the photos stay on your device)."
   Pictogram/ARASAAC and text buttons transfer fully.
   - Rationale (reviewer-confirmed): the word is the communicative core of an
     AAC button, so degrading a photo tile to its label preserves meaning
     ("cup" still says cup), whereas excluding the button drops its word
     entirely. `label`/`voice_out` is a required field, so it is always
     meaningful standalone. Dropping the photo is also the privacy-preserving
     choice: the child's photos never leave the tablet, which reinforces the
     "nothing leaves the device" pillar rather than straining it.
   - Rejected for v1: a zip-with-images container (needs an importer rewrite,
     a new pack format, and share-UTI changes) and base64-inlining photos into
     JSON (bloats the file, the schema does not support it, and silently
     embedding a child's photos into a shared file is privacy-surprising). Both
     remain viable v2 paths if photo fidelity is judged necessary.

3. **Privacy framing (load-bearing).** This is the first feature where user
   data intentionally leaves the device in a product whose pillar is "nothing
   leaves the device." It is parent-initiated and explicit (the parent taps
   Share and picks a recipient through the OS share sheet), and the pack
   contains only the vocabulary the parent built (labels, words, pictogram
   references), never event logs, bandit state, or photos. The `/privacy` page
   and the in-app privacy copy must state that the parent *may choose* to share
   a vocabulary board and that nothing is shared automatically. Confirm both
   surfaces reflect user-initiated sharing before this ships.
   - **The shared words can be personal** (a sibling's name, a private routine,
     a medical term), not generic "vocabulary" in the abstract. The share notice
     and the `/privacy` copy must say plainly that the parent is sharing the
     **words they authored**, so the off-device data path is legible and the
     parent can judge what they are handing to another family.
   - Reconcile the existing in-app privacy copy: `howWeKnowBody1` currently says
     the *only* way data leaves the device is "Share crash logs." Once sharing
     ships, that copy must name vocabulary-board sharing as a second,
     parent-initiated path.

4. **UI + temp-file lifecycle.** A "Share this board" action in the
   parent-facing surface (Settings / the board editor), behind the same parental
   gate pattern used elsewhere. It writes the export `.json` to a temp dir, hands
   it to the OS share sheet via `share_plus` (already a dependency), and
   **deletes the temp file after the share sheet returns** so a child's
   vocabulary export does not linger in a readable cache. The recipient imports
   via the existing Settings import flow.

5. **Website copy split.** Replace the single blurred "share the app" claim
   with two honest statements: "share your child's vocabulary" (real,
   near-term, no internet) and "install the app device-to-device" (Android-only
   / future, store-dependent on iOS). Reviewer-endorsed.

## Consequences

- A real, honest Tier-3 offline story ships: vocabulary travels device to
  device with no internet, built on the importer that already exists.
- Photo-backed custom buttons degrade to words-only in v1 (with a clear notice),
  pending a v2 decision on photo fidelity.
- New serialization (`toJson`) becomes a maintained inverse of the loader's
  parser; the round-trip test guards schema drift.
- App-binary device-to-device install stays explicitly future / Android-only.

## Testing

- Round-trip: export a board (bundled + custom + layout) -> import it through
  `BoardPackImporter` -> assert equality of the **meaningful fields** (labels,
  `labelByLocale`, category, position, `voice_out`, icon refs), NOT byte-equality
  and **NOT ids** (Decision 1 deliberately re-ids and namespaces on import, so
  ids are expected to differ; the next bullet owns id behavior).
- Re-id on import: the imported board gets a fresh `board_id` distinct from any
  recipient board; its button ids are namespaced and unique; no recipient board
  is overwritten; ADR 0009's one-id-one-board invariant holds post-import.
- Photo degradation: a board with a photo-backed custom button exports with the
  button present as text-only and no dangling image path; the notice count is
  correct.
- Temp-file cleanup: the export temp file is removed after the share completes.
- Gating: the Share action sits behind the parental gate and is absent from the
  child-facing surface.
