/// Atomic file write helper (review finding: crash/power-loss safety).
///
/// The parent-authored JSON stores (custom buttons, favourites, layout, and the
/// OTA overlay pointer) are rewritten in place. A plain writeAsString that is
/// interrupted mid-write (crash, battery death, OS kill) can leave a truncated,
/// unparseable file. The stores treat a corrupt file as "empty" and never crash,
/// but that silently DISCARDS the parent's customization.
///
/// Writing to a temp sibling and renaming closes the window: rename is atomic on
/// the same filesystem, so a reader sees either the old file or the fully new
/// one, never a half-written file.
library;

import 'dart:io';

/// Writes [contents] to [target] atomically: write a temp sibling, flush, then
/// rename over the target. The temp file is best-effort cleaned up on failure.
Future<void> writeStringAtomically(File target, String contents) async {
  final tmp = File('${target.path}.tmp');
  try {
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(target.path);
  } catch (e) {
    if (tmp.existsSync()) {
      try {
        await tmp.delete();
      } catch (_) {/* best-effort cleanup */}
    }
    rethrow;
  }
}
