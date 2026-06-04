/// Hitbox expansion geometry for glowing buttons.
///
/// A glowing button receives an invisibly expanded tap target to assist
/// motor planning per ADR 0003 section 3. The expansion is bounded by
/// the inter-button margin, halved:
///
///   max_per_side = min(crossAxisSpacing, mainAxisSpacing) / 2
///
/// This invariant is load-bearing. The PRD permits up to 3 to 4 buttons
/// to glow simultaneously and adjacent glowing buttons are possible.
/// Halving the gap guarantees two expanded hitboxes can never overlap
/// (combined expansion 2 * max_per_side equals the gap exactly at the
/// Maximum magnitude). A future contributor who "optimizes" this to the
/// full margin is silently shrinking non-glowing neighbors' tap targets
/// when an adjacent button glows, a regression we caught in review.
///
/// Settings exposes three semantic levels, NOT percentages:
///   None     -> 0% of max_per_side
///   Subtle   -> 50% (default)
///   Maximum  -> 100%
library;

import 'dart:math' as math;

/// Semantic level for the invisible tap-target expansion applied to a
/// glowing button. Stored in settings; consumed by [HitboxExpansion].
enum HitboxMagnitude {
  none,
  subtle,
  maximum;

  double get fraction => switch (this) {
        HitboxMagnitude.none => 0.0,
        HitboxMagnitude.subtle => 0.5,
        HitboxMagnitude.maximum => 1.0,
      };

  String toJson() => name;

  static HitboxMagnitude? tryParse(String? v) {
    for (final h in HitboxMagnitude.values) {
      if (h.name == v) return h;
    }
    return null;
  }
}

class HitboxExpansion {
  const HitboxExpansion._();

  /// Per-side expansion in logical pixels.
  ///
  /// Returned value is the amount a glowing tile may extend in each of
  /// the four directions (top, bottom, start, end). Two adjacent tiles
  /// both at this expansion add to exactly [crossAxisSpacing] or
  /// [mainAxisSpacing] (whichever is smaller, times two), which equals
  /// the actual gap and therefore preserves the no-overlap invariant.
  static double perSideExpansion({
    required double crossAxisSpacing,
    required double mainAxisSpacing,
    required HitboxMagnitude magnitude,
  }) {
    assert(crossAxisSpacing >= 0, 'crossAxisSpacing must be >= 0');
    assert(mainAxisSpacing >= 0, 'mainAxisSpacing must be >= 0');
    final maxPerSide =
        math.min(crossAxisSpacing, mainAxisSpacing) / 2.0;
    return maxPerSide * magnitude.fraction;
  }
}
