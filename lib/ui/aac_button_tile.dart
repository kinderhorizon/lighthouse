/// Single AAC button tile (redesign).
///
/// A rounded category-fill card: pictogram filling the upper area above a bold
/// ink label, a 1.5px darker "edge" border for quiet definition, a faint top
/// white sheen for tactility, and a soft rest shadow. Folders carry a dog-ear
/// chip top-trailing. Pressing scales the tile to 0.95 (the handoff press
/// affordance) without moving neighbors. Tiles NEVER move; only the glow
/// (drawn by [GlowEffect], one layer up) changes.
///
/// If the pictogram asset is missing (a board references an `icon_uri` not yet
/// vendored, or a custom file-path image went missing on restore), the tile
/// falls back to text rather than a broken-image glyph.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../logic/logic.dart';
import '../models/models.dart';
import 'theme/lighthouse_theme.dart';

class AACButtonTile extends StatefulWidget {
  const AACButtonTile({
    required this.button,
    required this.colorKey,
    required this.onTap,
    this.onLongPress,
    this.hideText = false,
    this.hideIcon = false,
    super.key,
  });

  final AACButton button;
  final Map<String, String> colorKey;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// When true, render the pictogram only and omit the text label (symbol-only
  /// mode, clinician setting). The Semantics label is kept regardless, so
  /// screen readers still announce the word.
  final bool hideText;

  /// When true, render the text label only and omit the pictogram (text-only
  /// mode, clinician setting; the complement of [hideText]). The Semantics
  /// label is unaffected. [hideText] and [hideIcon] are never both true (the
  /// settings notifier enforces it), but the build still guards against a blank
  /// tile defensively by always showing the label when the pictogram is gone.
  final bool hideIcon;

  static const _fallbackColor = Color(0xFFE0E0E0);

  @override
  State<AACButtonTile> createState() => _AACButtonTileState();
}

class _AACButtonTileState extends State<AACButtonTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final button = widget.button;
    final languageCode = Localizations.localeOf(context).languageCode;
    final label = button.labelFor(languageCode);
    final fill = resolveCategoryColor(
      button.category,
      widget.colorKey,
      fallback: AACButtonTile._fallbackColor,
    );
    final edge = categoryEdgeColor(fill);

    // The pictogram shows unless the clinician turned it off, and only when the
    // tile actually has one.
    final showIcon = !widget.hideIcon && button.iconUri.isNotEmpty;

    // Keep the text if hiding is off, or if the pictogram is not being shown
    // (turned off, absent, or a custom file-path image that can go missing): a
    // blank tile is unusable for a non-speaking child. Bundled `assets/`
    // pictograms are always present, so those may safely hide their label when
    // the symbol is shown.
    final showText = !widget.hideText ||
        !showIcon ||
        !button.iconUri.startsWith('assets/');

    final isFolder = button.type == AACButtonType.folder;

    return Semantics(
      label: label,
      button: true,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: LhMotion.fast,
        curve: LhMotion.ease,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: LhRadii.tileR,
            boxShadow: LhShadows.tileRest,
          ),
          child: Material(
            color: fill,
            borderRadius: LhRadii.tileR,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: (v) {
                if (v != _pressed) setState(() => _pressed = v);
              },
              child: Stack(
                children: [
                  // Faint top sheen for tactility (white .28 -> 0 at 38%).
                  const Positioned.fill(child: _Sheen()),
                  // Build-critical tile anatomy (designer rule 1): a vertical
                  // stack. The pictogram lives in its OWN box (BoxFit.contain,
                  // centered) and the label in its OWN band below; they never
                  // overlap. Ratios via flex so the split holds at every scale.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 7, 6, 6),
                    child: Column(
                      children: [
                        if (showIcon)
                          Expanded(
                            flex: 70,
                            child: Center(
                              child: _ButtonIcon(
                                  uri: button.iconUri, label: label),
                            ),
                          ),
                        if (showText)
                          Expanded(
                            flex: 28,
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: LhText.tileLabel,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // 1.5px edge border painted over the fill edge.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: LhRadii.tileR,
                          border: Border.all(color: edge, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // Folder dog-ear chip (top-trailing, mirrors under RTL).
                  if (isFolder)
                    const PositionedDirectional(
                      top: 7,
                      end: 7,
                      child: _FolderChip(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sheen extends StatelessWidget {
  const _Sheen();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: LhRadii.tileR,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x47FFFFFF), Color(0x00FFFFFF)],
            stops: [0.0, 0.38],
          ),
        ),
      ),
    );
  }
}

/// Soft dog-ear chip marking a tile as a folder that opens more words.
/// Ink-on-fill at low opacity so it reads against every pastel category.
class _FolderChip extends StatelessWidget {
  const _FolderChip();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: LhColors.ink.withValues(alpha: .14),
          borderRadius: const BorderRadius.all(Radius.circular(9)),
        ),
        child: const Icon(Icons.folder_rounded, size: 18, color: LhColors.ink),
      ),
    );
  }
}

class _ButtonIcon extends StatelessWidget {
  const _ButtonIcon({required this.uri, required this.label});

  final String uri;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Bundled pictograms are asset paths ("assets/..."); parent-authored
    // custom buttons (ADR 0012) carry an absolute file path. A missing image
    // falls back to the text-only layout: a broken-image icon would be worse
    // than no icon for a non-speaking child.
    const onError = _iconError;
    if (uri.startsWith('assets/')) {
      return Image.asset(
        uri,
        fit: BoxFit.contain,
        semanticLabel: label,
        errorBuilder: onError,
      );
    }
    return Image.file(
      File(uri),
      fit: BoxFit.contain,
      semanticLabel: label,
      errorBuilder: onError,
    );
  }

  static Widget _iconError(
          BuildContext context, Object error, StackTrace? stack) =>
      const SizedBox.shrink();
}
