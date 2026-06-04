/// Home-favourites editor (ADR 0013), redesign.
///
/// Parental (math-gated) surface to pin words to the home strip. "Pinned now"
/// shows the current pins as readable chips (pictogram + word + filled star);
/// "Add from a group" is a grouped, tappable category list. Pinning is stable;
/// nothing here reorders the child's strip on its own.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../logic/logic.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../tour/first_use_tip.dart';
import '../widgets/lh_widgets.dart';

class HomeFavouritesScreen extends ConsumerWidget {
  const HomeFavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final pins = (ref.watch(favouritesProvider).valueOrNull ?? const []).toSet();
    final boards = ref.watch(editableBoardsProvider).valueOrNull ?? const [];
    final suggestions =
        ref.watch(favouriteSuggestionsProvider).valueOrNull ?? const [];

    void pin(String boardId, String id) =>
        ref.read(favouritesProvider.notifier).pin(boardId, id);
    void unpin(String boardId, String id) =>
        ref.read(favouritesProvider.notifier).unpin(boardId, id);

    // Resolve the pinned (boardId, buttonId) refs back to their buttons so we
    // can show pictogram + word chips, and remember the colour_key per board
    // for the chip tint.
    final pinned = <({AACBoard board, AACButton button})>[];
    for (final b in boards) {
      for (final btn in b.buttons) {
        if (pins.contains((boardId: b.boardId, buttonId: btn.id))) {
          pinned.add((board: b, button: btn));
        }
      }
    }

    return FirstUseTipHost(
      tipKey: FirstUseTipsStore.favouritesKey,
      title: l10n.tipFavouritesTitle,
      body: l10n.tipFavouritesBody,
      builder: (context, anchorKey) => Scaffold(
      appBar: lhAppBar(context, title: l10n.homeFavouritesTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            LhHelpText(l10n.homeFavouritesIntro,
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 8)),
            if (pins.length >= kMaxFavourites)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                child: Text(
                  l10n.homeFavouritesFull(kMaxFavourites),
                  style: const TextStyle(
                      fontFamily: 'Atkinson Hyperlegible',
                      fontSize: 16,
                      color: Color(0xFFB3261E)),
                ),
              ),
            LhSectionLabel(l10n.homeFavouritesPinnedNow, key: anchorKey),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: pinned.isEmpty
                  ? Text(l10n.homeFavouritesEmpty,
                      style: const TextStyle(
                          fontFamily: 'Atkinson Hyperlegible',
                          fontSize: 16,
                          color: LhColors.ink3))
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final p in pinned)
                          _PinnedChip(
                            label: p.button.labelFor(lang),
                            iconUri: p.button.iconUri,
                            color: resolveCategoryColor(
                              p.button.category,
                              p.board.colorKey,
                              fallback: LhColors.cream2,
                            ),
                            onRemove: () => unpin(p.board.boardId, p.button.id),
                          ),
                      ],
                    ),
            ),
            if (suggestions.isNotEmpty) ...[
              LhSectionLabel(l10n.homeFavouritesSuggested),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in suggestions)
                      ActionChip(
                        avatar: const Icon(Icons.star_outline_rounded, size: 18),
                        label: Text(s.button.labelFor(lang)),
                        onPressed: () => pin(s.ref.boardId, s.button.id),
                      ),
                  ],
                ),
              ),
            ],
            LhSectionLabel(l10n.homeFavouritesAllWords),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                decoration: BoxDecoration(
                  color: LhColors.surface,
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  border: Border.all(color: LhColors.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < boards.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: LhColors.line),
                      _GroupTile(
                        board: boards[i],
                        lang: lang,
                        pins: pins,
                        onPin: pin,
                        onUnpin: unpin,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.board,
    required this.lang,
    required this.pins,
    required this.onPin,
    required this.onUnpin,
  });

  final AACBoard board;
  final String lang;
  final Set<({String boardId, String buttonId})> pins;
  final void Function(String boardId, String id) onPin;
  final void Function(String boardId, String id) onUnpin;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Strip the ExpansionTile's own dividers; the card draws hairlines.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(board.boardNameFor(lang), style: LhText.rowTitle),
        children: [
          for (final btn in board.buttons)
            if (btn.type != AACButtonType.folder)
              _WordRow(
                label: btn.labelFor(lang),
                pinned:
                    pins.contains((boardId: board.boardId, buttonId: btn.id)),
                onToggle: (nowPinned) => nowPinned
                    ? onPin(board.boardId, btn.id)
                    : onUnpin(board.boardId, btn.id),
              ),
        ],
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.label,
    required this.pinned,
    required this.onToggle,
  });

  final String label;
  final bool pinned;
  final void Function(bool nowPinned) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 20, right: 8),
      title: Text(label, style: LhText.body),
      trailing: IconButton(
        icon: Icon(pinned ? Icons.star_rounded : Icons.star_outline_rounded),
        color: pinned ? LhColors.amberDeep : LhColors.ink3,
        tooltip: pinned
            ? AppLocalizations.of(context).homeFavouritesUnpin
            : AppLocalizations.of(context).homeFavouritesPin,
        onPressed: () => onToggle(!pinned),
      ),
    );
  }
}

class _PinnedChip extends StatelessWidget {
  const _PinnedChip({
    required this.label,
    required this.iconUri,
    required this.color,
    required this.onRemove,
  });

  final String label;
  final String iconUri;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: LhColors.line, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconUri.isNotEmpty) ...[
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.all(Radius.circular(9)),
              ),
              child: _ChipIcon(uri: iconUri),
            ),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: const TextStyle(
                fontFamily: 'Atkinson Hyperlegible',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LhColors.ink,
              )),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.star_rounded, size: 20, color: LhColors.amberDeep),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipIcon extends StatelessWidget {
  const _ChipIcon({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    Widget onError(BuildContext _, Object __, StackTrace? ___) =>
        const SizedBox.shrink();
    if (uri.startsWith('assets/')) {
      return Image.asset(uri, fit: BoxFit.contain, errorBuilder: onError);
    }
    return Image.file(File(uri), fit: BoxFit.contain, errorBuilder: onError);
  }
}
