/// Shared boards (ADR 0015 amendment): putting a board someone shared on the
/// child's board, now or later.
///
/// Clinical testing: after "Add board" the app only said the board was added,
/// so the parent did not know where it went (it was stored, but nothing on the
/// child's board opened it). Now, right after adding, the parent is asked to
/// put it on the board now or later; "later" says where to find it (Settings,
/// Shared boards). Putting it on the board opens the editor already asking
/// where it goes: an empty square, or a word to put it in place of (on a full
/// page that is the only choice, and the hint says so).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/state.dart';
import '../edit/board_edit_screen.dart';
import '../theme/lighthouse_theme.dart';
import '../widgets/lh_widgets.dart';

/// Opens the editor on the home board, asking where the shared board [id]
/// (shown as [name]) should go.
Future<void> openSharedBoardPlacement(
  BuildContext context, {
  required String id,
  required String name,
}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BoardEditScreen(
        rootBoardId: kHomeBoardId,
        placeSharedBoard: (id: id, name: name),
      ),
    ));

/// Asked right after a shared board is added: put it on the board now, or
/// later. Choosing later (or closing the dialog) says where to find it.
Future<void> offerToPlaceSharedBoard(
  BuildContext context, {
  required String id,
  required String name,
}) async {
  final l10n = AppLocalizations.of(context);
  final now = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(l10n.importedBoardTitle),
      content: Text(l10n.importedBoardBody(name)),
      actions: [
        TextButton(
          key: const ValueKey('imported_later'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.importedBoardLater),
        ),
        FilledButton(
          key: const ValueKey('imported_place'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.importedBoardPlace),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (now == true) {
    await openSharedBoardPlacement(context, id: id, name: name);
  } else {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(l10n.importedBoardLaterToast(name)),
      ));
  }
}

class SharedBoardsScreen extends ConsumerWidget {
  const SharedBoardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final registry = ref.watch(boardRegistryProvider).valueOrNull;
    final boards = ref.watch(editableBoardsProvider).valueOrNull ?? const [];
    final customs = ref.watch(customButtonsProvider).valueOrNull ?? const [];
    final byId = {for (final b in boards) b.boardId: b};
    final shared = [
      for (final id in registry?.importedBoardIds() ?? const <String>[])
        if (byId[id] != null) byId[id]!,
    ];

    return Scaffold(
      appBar: lhAppBar(context, title: l10n.sharedBoardsTitle),
      body: SafeArea(
        child: shared.isEmpty
            ? LhEmptyState(
                icon: Icons.dashboard_outlined,
                headline: l10n.sharedBoardsTitle,
                body: l10n.sharedBoardsEmpty,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                itemCount: shared.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (context, i) {
                  final board = shared[i];
                  final name = board.boardNameFor(lang);
                  final onBoard =
                      customs.any((c) => c.linkId == board.boardId);
                  return Column(
                    key: ValueKey('shared_board_${board.boardId}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: LhText.rowTitle),
                      const SizedBox(height: 2),
                      Text(
                        onBoard
                            ? l10n.sharedBoardsOnBoard
                            : l10n.sharedBoardsNotOnBoard,
                        style: LhText.rowSubtitle,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        key: ValueKey('shared_place_${board.boardId}'),
                        onPressed: () => openSharedBoardPlacement(context,
                            id: board.boardId, name: name),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.sharedBoardsPlace),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
