/// Visual treatment for the next-likely-word glow.
///
/// All treatments mark the SAME posterior-mean-based level (none / shimmer /
/// gold per [computeGlowLevel]); they differ only in how that mark is drawn.
/// The four treatments plus an off switch are offered under Advanced > Glow
/// style (redesign handoff). The glow NEVER moves a tile; only the treatment
/// on the already-fixed tile changes.
///
/// * halo - amber ring + outer bloom + a slow pulse (recommended default)
/// * ring - a crisp inset amber ring (reads close to "selected")
/// * lift - the tile raises with a warm underline bar
/// * dot  - a quiet corner dot, no motion (calmest, for movement-distracted kids)
/// * off  - no glow at all
///
/// Migration: the pre-redesign values were `pulse` / `halo` / `brightness`.
/// `halo` carries over; `pulse` and `brightness` are no longer valid tokens, so
/// [tryParse] returns null for them and the reader falls back to the default
/// ([halo]), which is the same warm pulsing look the old `pulse` default gave.
library;

enum GlowStyle {
  halo,
  ring,
  lift,
  dot,
  off;

  /// Whether any glow is drawn at all.
  bool get showsGlow => this != GlowStyle.off;

  String toJson() => name;

  static GlowStyle? tryParse(String? v) {
    for (final s in GlowStyle.values) {
      if (s.name == v) return s;
    }
    return null;
  }
}
