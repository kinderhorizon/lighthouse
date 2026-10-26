/// Colour choice for a button or category the parent makes (ADR 0022).
///
/// Grey plus the six Fitzgerald colours the built-in boards use, each shown as
/// a swatch with its meaning spelled out ("Green: action words"), so a parent
/// can match the words a new tile belongs with. Large (48pt) targets, a clear
/// tick on the chosen one, and a screen-reader label per swatch.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../logic/logic.dart';
import '../../models/models.dart';
import '../aac_button_tile.dart';
import '../theme/lighthouse_theme.dart';

/// The name a parent sees for [color] (null = grey).
String tileColorName(AppLocalizations l10n, TileColor? color) =>
    switch (color) {
      null => l10n.tileColorGrey,
      TileColor.yellow => l10n.tileColorYellow,
      TileColor.green => l10n.tileColorGreen,
      TileColor.orange => l10n.tileColorOrange,
      TileColor.blue => l10n.tileColorBlue,
      TileColor.pink => l10n.tileColorPink,
      TileColor.purple => l10n.tileColorPurple,
    };

/// The fill a swatch (and a tile) shows for [color] (null = grey).
Color tileColorFill(TileColor? color) => color == null
    ? AACButtonTile.fallbackColor
    : parseHexColor(color.hex) ?? AACButtonTile.fallbackColor;

class TileColorPicker extends StatelessWidget {
  const TileColorPicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// The chosen colour; null = grey.
  final TileColor? value;
  final ValueChanged<TileColor?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.tileColorLabel,
            style: LhText.rowSubtitle.copyWith(
                color: LhColors.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in <TileColor?>[null, ...TileColor.values])
              _Swatch(
                key: ValueKey('tile_color_${c?.name ?? 'grey'}'),
                fill: tileColorFill(c),
                label: tileColorName(l10n, c),
                selected: c == value,
                onTap: () => onChanged(c),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // The chosen colour's meaning, so the choice is never colour-only.
        Text(tileColorName(l10n, value), style: LhText.rowSubtitle),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.fill,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color fill;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));
    // The swatch speaks for itself (its colour name), so the inner ink is
    // excluded; the tap action is declared here so a screen reader can still
    // choose it.
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? const BorderSide(color: LhColors.brown, width: 3)
              : BorderSide(color: categoryEdgeColor(fill), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: selected
                ? const Icon(Icons.check_rounded, color: LhColors.brown, size: 28)
                : null,
          ),
        ),
      ),
    );
  }
}
