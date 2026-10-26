/// Parent-chosen tile colours (ADR 0022).
///
/// A parent can give a button they made one of the six Fitzgerald Key fills the
/// bundled boards already use, so it matches the words around it. The choice is
/// limited to those six on purpose: a tile's colour tells the child what kind of
/// word it is, and a free colour picker would break that code (and could make a
/// dark tile whose label is hard to read). Display only: the button's category,
/// and so glow, learning and sentence rules, never changes.
library;

/// The six Fitzgerald fills, in the order the picker shows them. Each [hex]
/// matches a `color_key` value in the bundled boards.
enum TileColor {
  /// People and pronouns.
  yellow('#FFFFA6'),

  /// Action words.
  green('#C2FFC2'),

  /// Things, food, and places.
  orange('#FFD9A6'),

  /// Feelings and yes / no.
  blue('#A6D9FF'),

  /// Social words and urgent needs.
  pink('#FFC2C2'),

  /// Questions and time.
  purple('#E6A6FF');

  const TileColor(this.hex);

  /// `#RRGGBB`, upper case, as stored in JSON.
  final String hex;

  /// The palette entry for a stored or imported value, or null when [value] is
  /// absent or not one of the six. Case-insensitive; the leading `#` is
  /// optional. An unknown value falls back to the category colour rather than
  /// failing the whole board (it is cosmetic, and may come from a shared pack).
  static TileColor? fromHex(Object? value) {
    if (value is! String) return null;
    final v = value.trim().toUpperCase();
    final hex = v.startsWith('#') ? v : '#$v';
    for (final c in values) {
      if (c.hex == hex) return c;
    }
    return null;
  }

  /// The one palette colour every category on a board uses, or null when the
  /// board mixes colours (Home) or uses a colour outside the palette. A new
  /// button on a single-colour board (Food, People, ...) starts in that colour,
  /// so it joins the board's colour group without the parent having to pick.
  static TileColor? soleColorOf(Map<String, String> colorKey) {
    TileColor? only;
    for (final value in colorKey.values) {
      final c = fromHex(value);
      if (c == null) return null;
      if (only != null && only != c) return null;
      only = c;
    }
    return only;
  }
}
