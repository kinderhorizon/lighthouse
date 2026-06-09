/// Home favourites strip (ADR 0013).
///
/// A stable, horizontal row of the parent's PINNED buttons, shown on the home
/// board only and hidden entirely when there are no pins (no chrome by
/// default). Tapping a favourite is a normal communication act: it routes to
/// the same handler as the button on its own board (speak + append to the
/// sentence bar + feed the bandit).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/logic.dart';
import '../models/models.dart';
import '../state/state.dart';
import 'theme/lighthouse_theme.dart';

class FavouritesStrip extends ConsumerWidget {
  const FavouritesStrip({
    required this.onTap,
    required this.colorKey,
    this.onLongPress,
    this.hideText = false,
    this.hideIcon = false,
    super.key,
  });

  final void Function(AACButton button) onTap;

  /// On-request mode routes the communication act through a long-press, so the
  /// strip mirrors the grid's long-press path; null in every other mode (where a
  /// long-press handler would otherwise sit in the gesture arena and cancel
  /// taps, the grid's item-7 issue applied to favourites).
  final void Function(AACButton button)? onLongPress;

  /// Category -> hex color map (the home board's), so each favourite is colored
  /// by its Fitzgerald category exactly like the grid tile it mirrors.
  final Map<String, String> colorKey;

  /// Mirror the grid's tile-content settings so a favourite looks like the tile
  /// it stands in for. Both can never be on at once (enforced upstream); the
  /// never-blank guard below keeps a favourite from losing both.
  final bool hideText;
  final bool hideIcon;

  static const double height = 84;
  static const _ink = LhColors.ink;
  static const _fallbackColor = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(homeFavouritesProvider).valueOrNull ?? const [];
    if (favs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: favs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _FavTile(
          button: favs[i],
          onTap: onTap,
          onLongPress: onLongPress,
          colorKey: colorKey,
          hideText: hideText,
          hideIcon: hideIcon,
        ),
      ),
    );
  }
}

class _FavTile extends StatelessWidget {
  const _FavTile({
    required this.button,
    required this.onTap,
    required this.colorKey,
    this.onLongPress,
    this.hideText = false,
    this.hideIcon = false,
  });

  final AACButton button;
  final void Function(AACButton) onTap;
  final void Function(AACButton)? onLongPress;
  final Map<String, String> colorKey;
  final bool hideText;
  final bool hideIcon;

  @override
  Widget build(BuildContext context) {
    final label = button.labelFor(Localizations.localeOf(context).languageCode);
    // Mirror the grid tile: show the pictogram unless it is turned off / absent,
    // and keep the label whenever the word setting allows OR no pictogram is
    // shown, so a favourite is never blank (the star marker is not a pictogram).
    final showIcon = !hideIcon && button.iconUri.isNotEmpty;
    final showText = !hideText || !showIcon;
    // Color by category, mirroring the grid (clinical review: white tiles lost the
    // color coding the rest of the board relies on). A folder favourite keeps
    // its *_nav category color; an unknown category falls back to grey.
    final tileColor = resolveCategoryColor(
      button.category,
      colorKey,
      fallback: FavouritesStrip._fallbackColor,
    );
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: tileColor,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: categoryEdgeColor(tileColor), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(button),
          onLongPress:
              onLongPress == null ? null : () => onLongPress!(button),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showIcon) ...[
                  _FavIcon(uri: button.iconUri, label: label),
                  if (showText) const SizedBox(width: 8),
                ],
                if (showText)
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Atkinson Hyperlegible',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: FavouritesStrip._ink,
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded, size: 18, color: LhColors.amberDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavIcon extends StatelessWidget {
  const _FavIcon({required this.uri, required this.label});

  final String uri;
  final String label;

  @override
  Widget build(BuildContext context) {
    const onError = _shrink;
    if (uri.startsWith('assets/')) {
      return Image.asset(uri, height: 44, fit: BoxFit.contain,
          semanticLabel: label, errorBuilder: onError);
    }
    return Image.file(File(uri), height: 44, fit: BoxFit.contain,
        semanticLabel: label, errorBuilder: onError);
  }

  static Widget _shrink(BuildContext c, Object e, StackTrace? s) =>
      const SizedBox.shrink();
}
