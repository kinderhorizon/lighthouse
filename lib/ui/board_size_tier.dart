/// Board size tier (handoff Rule 3: phone / small screens, "rethink, don't
/// shrink").
///
/// An 8-column, 56-tile core board is sized for a ~10" tablet. On a phone it
/// falls below the legibility floor (and landscape is worse). The fix is NOT to
/// shrink the tiles: it is to pick a COLUMN COUNT by the device's width tier and
/// LOCK it across rotation, keep tiles at a legible fixed size, and SCROLL the
/// board vertically when the full vocabulary does not fit. Tiles keep their
/// reading order; only the wrap width changes per device (never per rotation),
/// so muscle memory holds within a device.
///
/// The tier is decided from the device's SHORTEST side so it is identical in
/// portrait and landscape (locked across rotation, per the rule). The large
/// tablet keeps the board's native column count and fills the screen (the
/// existing, tested iPad behavior); smaller tiers reduce columns and scroll.
library;

/// Device width tiers. Thresholds use the shortest side (orientation-invariant).
enum BoardSizeTier {
  /// Phones. 5 columns, board scrolls. (`shortestSide < 600`.)
  phone,

  /// Small tablets / 7-8" Android, older/mini iPads. 6 columns, board scrolls.
  /// (`600 <= shortestSide < 820`.)
  smallTablet,

  /// 11"+ iPads, the primary form factor. Native column count, fills the
  /// screen (unchanged behavior). (`shortestSide >= 820`.)
  largeTablet,
}

/// The board layout for a device: how many columns to wrap at, and whether the
/// board scrolls (reduced-column tiers) or fills the screen (large tablet).
class BoardSizing {
  const BoardSizing({required this.tier, required this.columns, required this.scrolls});

  final BoardSizeTier tier;

  /// Columns to lay the board out in. Never more than the board's native count.
  final int columns;

  /// True for reduced-column tiers: keep tiles at a legible fixed height and
  /// scroll vertically rather than shrinking below the floor. False on a large
  /// tablet, where the native board fills the screen.
  final bool scrolls;
}

/// Tier from the device shortest side. 820 keeps the 11" iPad (834pt) and the
/// 10th-gen iPad (820pt) on the native 8-column fill layout (the tested
/// primary); iPad mini / 9.7" (744-768) drop to the 6-column scroll layout.
BoardSizeTier boardSizeTierFor(double shortestSide) {
  if (shortestSide < 600) return BoardSizeTier.phone;
  if (shortestSide < 820) return BoardSizeTier.smallTablet;
  return BoardSizeTier.largeTablet;
}

/// Resolve the board sizing for a device, clamped to the board's native column
/// count (a sub-board narrower than the tier never gains empty columns).
BoardSizing boardSizingFor({
  required double shortestSide,
  required int nativeColumns,
}) {
  final tier = boardSizeTierFor(shortestSide);
  switch (tier) {
    case BoardSizeTier.phone:
      return BoardSizing(
        tier: tier,
        columns: nativeColumns < 5 ? nativeColumns : 5,
        scrolls: true,
      );
    case BoardSizeTier.smallTablet:
      return BoardSizing(
        tier: tier,
        columns: nativeColumns < 6 ? nativeColumns : 6,
        scrolls: true,
      );
    case BoardSizeTier.largeTablet:
      return BoardSizing(tier: tier, columns: nativeColumns, scrolls: false);
  }
}
