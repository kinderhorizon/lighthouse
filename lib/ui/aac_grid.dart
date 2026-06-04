/// AAC board grid (redesign).
///
/// Lays out the board's `gridDimensions.rows x gridDimensions.cols` tiles at
/// the redesign gutter (14px) and outer padding (10/16/18). Positions without a
/// button render as empty space (sparse boards are allowed by the schema).
///
/// Two height modes:
/// * fill (default, home board): the grid flexes to fill the remaining height,
///   so the home layout the child learns always fills the screen.
/// * topAlign (sub-board): tiles take a fixed, image-forward portrait extent
///   and sit at the top, leaving calm empty space below (handoff: sub-board
///   tiles stay large and are NOT stretched to fill the screen height).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/logic.dart';
import '../models/models.dart';
import 'aac_button_tile.dart';
import 'glow_effect.dart';

/// AAC board grid. See the spacing/hitbox model on [AACGrid] in the original
/// (ADR 0006): the inter-button gap lives as per-cell internal padding so a
/// glowing tile can expand its tap target into the gap WITHOUT moving any
/// neighbor (no layout shift).
class AACGrid extends StatelessWidget {
  const AACGrid({
    required this.board,
    required this.onButtonTap,
    this.onButtonLongPress,
    this.glow = const {},
    this.glowStyle = GlowStyle.halo,
    this.hitboxMagnitude = HitboxMagnitude.subtle,
    this.hideTileText = false,
    this.hidePictogram = false,
    this.topAlign = false,
    this.columns,
    this.scroll = false,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 12),
    this.crossAxisSpacing = 10,
    this.mainAxisSpacing = 10,
    super.key,
  });

  final AACBoard board;
  final ValueChanged<AACButton> onButtonTap;
  final ValueChanged<AACButton>? onButtonLongPress;

  /// Per-button glow level. Buttons not present render without a glow.
  final Map<String, GlowLevel> glow;

  /// Visual treatment for every glowing tile. Sourced from `settings.glowStyle`.
  final GlowStyle glowStyle;

  /// How far a glowing tile's tap target expands into the gap.
  final HitboxMagnitude hitboxMagnitude;

  /// When true, tiles render the pictogram only (no text label).
  final bool hideTileText;

  /// When true, tiles render the text label only (no pictogram). The complement
  /// of [hideTileText]; never true at the same time (enforced upstream).
  final bool hidePictogram;

  /// When true, render a fixed-extent, top-aligned grid (sub-board look)
  /// instead of stretching rows to fill the available height.
  final bool topAlign;

  /// Column count to lay the board out in. When null, the board's native
  /// `gridDimensions.cols` is used (the tablet layout). On phones / small
  /// tablets this is fewer columns (handoff Rule 3, see [BoardSizing]); the
  /// board is reflowed into this width in reading order.
  final int? columns;

  /// Phone / small-screen mode: keep tiles at a legible fixed height and SCROLL
  /// the board vertically rather than shrinking below the legibility floor.
  /// Tiles reflow into [columns] in their original reading order; positions are
  /// stable for the device (column count is locked across rotation upstream).
  final bool scroll;

  final EdgeInsetsGeometry padding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    final cols = board.gridDimensions.cols;
    // In top-align (sub-board) mode, render only the rows that actually hold
    // buttons. A sub-board often declares more rows than it fills (e.g. 6 rows
    // for a 2-row board); rendering the empty trailing rows would add scroll
    // height and leave a sparse-looking board. Home (fill mode) keeps all its
    // declared rows so it fills the screen.
    final int rows;
    if (topAlign) {
      var maxRow = -1;
      for (final b in board.buttons) {
        if (b.position.row > maxRow) maxRow = b.position.row;
      }
      rows = maxRow >= 0 ? maxRow + 1 : board.gridDimensions.rows;
    } else {
      rows = board.gridDimensions.rows;
    }

    // Half-gap that lives inside each cell as padding (the hitbox model).
    final padX = crossAxisSpacing / 2.0;
    final padY = mainAxisSpacing / 2.0;

    /// Sub-board row-height cap (designer rule 2 exception): a few-row board
    /// caps its row height and top-aligns so a 2-row board does not balloon to
    /// full height; it still fills the width.
    const subBoardMaxRowExtent = 200.0;

    // The padded glow+tile for one button. The inter-tile gap lives as per-cell
    // padding so a glowing tile can expand its tap target into the gap WITHOUT
    // moving any neighbor. Shared by the position-based grid (fill / top-align)
    // and the reflowed scroll grid (phone / small screens).
    Widget cellForButton(AACButton btn) {
      // When the glow style is Off, the board must give NO next-word hint of
      // any kind (clinical review): not the glow, and not the silent hitbox growth a
      // glowing tile would otherwise get (which read as a "slight lift"). So a
      // non-showing style forces every tile to the none level here, before it
      // can affect either the visual or the tap-target size.
      final level =
          glowStyle.showsGlow ? (glow[btn.id] ?? GlowLevel.none) : GlowLevel.none;
      // A glowing tile shrinks its internal padding by the expansion, growing
      // its Material toward the neighbor (no layout shift for the others).
      final expansion = level.isGlowing
          ? HitboxExpansion.perSideExpansion(
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
              magnitude: hitboxMagnitude,
            )
          : 0.0;
      final cellPadding = EdgeInsets.symmetric(
        horizontal: math.max(0.0, padX - expansion),
        vertical: math.max(0.0, padY - expansion),
      );
      return Padding(
        padding: cellPadding,
        child: GlowEffect(
          level: level,
          style: glowStyle,
          child: AACButtonTile(
            button: btn,
            colorKey: board.colorKey,
            hideText: hideTileText,
            hideIcon: hidePictogram,
            onTap: () => onButtonTap(btn),
            onLongPress: onButtonLongPress == null
                ? null
                : () => onButtonLongPress!(btn),
          ),
        ),
      );
    }

    Widget cell(int index) {
      final row = index ~/ cols;
      final col = index % cols;
      final btn = board.buttonAt((row: row, col: col));
      if (btn == null) return const SizedBox.shrink();
      return cellForButton(btn);
    }

    // The board FILLS the available space in BOTH orientations (designer rule
    // 2). The 8 columns and every tile's exact row/column never change; only
    // the cell SHAPE adapts to the live area, so portrait cells are tallish and
    // landscape cells get wider and bigger. childAspectRatio is derived from
    // the LayoutBuilder constraints, never hard-coded, and the board is NOT
    // wrapped in a FittedBox (that letterboxed it and wasted the width). The
    // pictogram stays BoxFit.contain in its own box (the tile widget), so a
    // wider cell just adds side padding and never distorts the symbol.
    return LayoutBuilder(
      builder: (context, constraints) {
        final padded = padding.resolve(Directionality.of(context));
        final availW = constraints.maxWidth - padded.horizontal;
        final availH = constraints.maxHeight - padded.vertical;
        final cellW = availW / cols;

        // Phone / small-screen mode (handoff Rule 3): reflow the board into
        // [columns] in reading order and SCROLL vertically, keeping tiles at a
        // legible fixed height instead of shrinking below the floor. Column
        // count is locked across rotation upstream (it is chosen from the
        // device's shortest side), so a rotation reshapes nothing here; only
        // the cell HEIGHT eases (shorter in landscape where vertical space is
        // scarce, matching the prototype's 132 portrait / 118 landscape).
        if (scroll) {
          final scrollCols = columns ?? cols;
          final ordered = [...board.buttons]..sort((a, b) {
              final byRow = a.position.row.compareTo(b.position.row);
              return byRow != 0
                  ? byRow
                  : a.position.col.compareTo(b.position.col);
            });
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final cellExtent = isLandscape ? 124.0 : 138.0;
          return Padding(
            padding: padded,
            child: GridView.builder(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: scrollCols,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
                mainAxisExtent: cellExtent,
              ),
              itemCount: ordered.length,
              itemBuilder: (context, i) => cellForButton(ordered[i]),
            ),
          );
        }

        if (topAlign) {
          // Sub-board: fill the width, but cap row height and top-align so a
          // 2-row board does not balloon to full height.
          final fillExtent = availH / rows;
          final rowExtent =
              fillExtent.isFinite && fillExtent > 0 && fillExtent < subBoardMaxRowExtent
                  ? fillExtent
                  : subBoardMaxRowExtent;
          return Padding(
            padding: padded,
            child: GridView.builder(
              physics: const ClampingScrollPhysics(),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
                mainAxisExtent: rowExtent,
              ),
              itemCount: rows * cols,
              itemBuilder: (context, index) => cell(index),
            ),
          );
        }

        // Home (fill width AND height): the cell aspect comes straight from the
        // available area, so cells reshape per orientation and the board never
        // letterboxes.
        final cellH = availH / rows;
        final rawAspect = cellW / cellH;
        final aspect = (rawAspect.isFinite && rawAspect > 0) ? rawAspect : 1.0;
        return Padding(
          padding: padded,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: 0,
              mainAxisSpacing: 0,
              childAspectRatio: aspect,
            ),
            itemCount: rows * cols,
            itemBuilder: (context, index) => cell(index),
          ),
        );
      },
    );
  }
}
