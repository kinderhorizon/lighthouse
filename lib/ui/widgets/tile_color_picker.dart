/// Colour choice for a button or category the parent makes (ADR 0022).
///
/// Grey plus the six Fitzgerald colours the built-in boards use, as a list in
/// which EVERY colour shows its meaning next to it ("Green: action words"), so
/// a parent can match the words a new tile belongs with without tapping each
/// colour to find out (clinical testing: even the clinician found the bare
/// swatches hard to choose from). Full-width 48pt rows, a tick on the chosen
/// one, and a screen-reader label per row.
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
        const SizedBox(height: 6),
        for (final c in <TileColor?>[null, ...TileColor.values])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _Swatch(
              key: ValueKey('tile_color_${c?.name ?? 'grey'}'),
              fill: tileColorFill(c),
              label: tileColorName(l10n, c),
              selected: c == value,
              onTap: () => onChanged(c),
            ),
          ),
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
    // The row speaks for itself (its colour name and meaning), so the inner
    // ink is excluded; the tap action is declared here so a screen reader can
    // still choose it.
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? LhColors.amberTint : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? const BorderSide(color: LhColors.brown, width: 2)
              : const BorderSide(color: LhColors.line2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(
                          color: categoryEdgeColor(fill), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: LhText.rowSubtitle.copyWith(
                        color: LhColors.ink,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_rounded,
                        color: LhColors.brown, size: 26),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
