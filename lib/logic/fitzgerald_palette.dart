/// Fitzgerald Key color resolution.
///
/// The Fitzgerald Key is the clinical AAC color-coding standard (yellow for
/// pronouns, green for verbs, orange for nouns, blue for feelings, etc.).
/// See docs/CONTEXT.md and docs/adr/0003-cold-start-glow-and-onboarding.md.
///
/// Colors live in the board's `color_key` map, not in widget code. This keeps
/// the palette swappable per board (a future Spanish-localized board could
/// ship slightly different shades without a code change).
library;

import 'package:flutter/painting.dart';

/// Parses a #RRGGBB hex string into a [Color].
///
/// Returns null for malformed input. The caller decides on a fallback (e.g.,
/// a neutral grey for unknown categories) rather than this helper silently
/// substituting one.
Color? parseHexColor(String hex) {
  final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
  if (cleaned.length != 6 && cleaned.length != 8) return null;
  final intValue = int.tryParse(cleaned, radix: 16);
  if (intValue == null) return null;
  return cleaned.length == 6
      ? Color(0xFF000000 | intValue)
      : Color(intValue);
}

/// Resolves a button category (e.g., "verb", "needs") against a board's
/// color_key map, returning the matching color.
///
/// Returns [fallback] when the category is missing from the map or the
/// stored hex is malformed. Callers should never see a hardcoded fallback
/// in this codebase; the board's color_key is authoritative.
Color resolveCategoryColor(
  String category,
  Map<String, String> colorKey, {
  required Color fallback,
}) {
  final hex = colorKey[category];
  if (hex == null) return fallback;
  return parseHexColor(hex) ?? fallback;
}

/// The six redesign Fitzgerald fills mapped to their slightly darker "edge"
/// border, for quiet tile definition (handoff design tokens). Keyed by the
/// fill's 0xAARRGGBB value so it works regardless of which category alias
/// (e.g. `food` vs `places`) resolved to that fill.
const Map<int, Color> _fillToEdge = {
  0xFFE6A6FF: Color(0xFFC77FE6), // questions
  0xFFC2FFC2: Color(0xFF8FD79A), // actions / verbs
  0xFFFFFFA6: Color(0xFFDBD06A), // people / pronouns
  0xFFFFC2C2: Color(0xFFE89A9A), // social / negation
  0xFFA6D9FF: Color(0xFF79B6E6), // describing / feelings
  0xFFFFD9A6: Color(0xFFE4B377), // things / places
};

/// The 1.5px border color for a tile of the given [fill]. Uses the locked
/// edge for the six known Fitzgerald fills; for any other fill (custom board
/// color_key) it derives a slightly darker shade so the tile still reads as
/// framed rather than borderless.
Color categoryEdgeColor(Color fill) {
  final mapped = _fillToEdge[fill.toARGB32()];
  if (mapped != null) return mapped;
  final hsl = HSLColor.fromColor(fill);
  return hsl
      .withLightness((hsl.lightness * 0.82).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation * 1.05).clamp(0.0, 1.0))
      .toColor();
}
