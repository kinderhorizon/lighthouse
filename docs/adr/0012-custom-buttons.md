# ADR 0012: Parent-authored custom buttons

Status: Accepted (2026-05-29); Decision 1 amended by ADR 0014 (2026-05-30,
pending its re-review): custom-button id becomes slot-independent so a button
can be repositioned without colliding ids or orphaning learning.

## Context

The bundled vocabulary is fixed, but the things a specific child requests are
specific to that child (clinical-lead alpha feedback #9: families need to add
their own buttons to test meaningfully). A parent must be able to add a button
(picture + word) to a board, and it must survive app launches.

## Decision

1. **Overlay, not edit-in-place.** Bundled board JSON stays read-only assets.
   Custom buttons are persisted separately and overlaid at read time. A
   `CustomButton` is `{boardId, row, col, label, voiceOut, imagePath}`; on a
   slot collision the custom button wins (the editor only offers empty slots,
   so this is just robustness).

2. **Single integration point.** `applyCustomButtons(board, customs)` is a pure
   merge, applied in `activeBoardProvider`. Every consumer (grid, glow
   predictions) sees the merged board automatically; the board stack and the
   loader stay pure.

3. **Persistence as a JSON file**, not an Isar collection: avoids a schema
   version bump (ADR 0005) and mirrors the existing imported-boards pattern
   (`custom_buttons.json` + copied images under `custom_images/` in the app
   support directory, which is excluded from OS backup per ADR 0002). Image
   paths are persisted **relative** (filename only) and re-resolved against the
   live support directory at load time; the in-memory path is absolute for the
   tile. A persisted absolute path would embed the iOS app-container UUID,
   which is not stable across delete-reinstall or device restore, so the photo
   would dangle. (Folded in from the independent technical review.)

4. **Images are device photos.** A parent picks a photo (the child's actual cup,
   toy, snack); it is copied into the app support directory so it is stable.
   The tile renders an absolute file path with `Image.file` and a bundled
   `assets/...` path with `Image.asset`.

   Picker (amended 2026-06-02): photos are chosen via `image_picker`
   (`pickImage(source: gallery)`), which is the system photo picker (PHPicker
   on iOS 14+, Android photo picker). The original `file_picker`
   `FileType.image` was dropped because its iOS dependency
   (`DKImagePickerController`/`DKCamera`) linked the Photos, Camera, and
   CoreLocation frameworks and tripped App Store 90683 for all three; PHPicker
   needs no permission prompt and no usage string. See ADR 0016. The
   `imageSource` stays a `File` (the picker yields a path we wrap), so the
   `CustomButtonStore` import + size/extension validation are unchanged.

5. **Speech via system TTS.** Arbitrary parent words have no pre-rendered neural
   clip, so they fall through to system TTS (FallbackTTSEngine). Acceptable:
   custom words are by definition outside the fixed vocabulary ADR 0008 covers.

6. **Behind the parental gate.** Adding/removing buttons lives behind the same
   math gate as Settings, so a child cannot alter their own board.

## Consequences

- Custom buttons are tappable, speak, append to the sentence bar, and can glow
  like any word; they carry category `custom`.
- No neural audio for custom words (system TTS only) until/unless a future
  on-device synthesis path covers them.
- Home is full (56/56); custom buttons target boards with empty slots. Putting
  a custom word on home is the job of promote-to-home (ADR 0013 / #108).
- Authored by the implementer; independent technical review per cadence.

## Post-alpha (deliberately deferred)

- **Portability vs the backup exclusion.** ADR 0002 excludes the support dir
  from OS backup for behavioral-privacy reasons; that now also means custom
  vocabulary + photos do not survive a device change. The photos already live
  in the parent's backed-up photo library, so the privacy gain on the copies is
  marginal. Revisit with an explicit export path or a backup-included location
  for parent-authored content (separate from the behavioral DB).
- **Custom buttons are invisible to the semantic boost (ADR 0011)** because
  they carry category `custom`. Letting the parent pick a real category at
  creation (so a custom "juice" lights up after "drink") would integrate the
  two. Future refinement.
- **Parent-recorded audio** for custom buttons would give custom words a real
  voice (warm + familiar) and is the only viable path for custom Arabic words,
  where no bundled clip is possible and system Arabic TTS is unreliable.
