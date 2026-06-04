/// Parent board editor (ADR 0014, redesigned per the v5 handoff / ADR 0019).
///
/// A gated, child-unreachable mode for managing the CURRENT board. Three
/// direct-manipulation models replace the old tap -> menu -> "Move" flow:
///
/// 1. ARRANGE (default): tiles jiggle (reduced-motion gated); long-press + drag
///    reorders (insertion, neighbours shift); a plain TAP opens a quick-action
///    sheet (record voice, replace picture, pin/unpin, hide/show, delete custom).
/// 2. SELECT (multi-select): the app-bar "Select" toggle; tap tiles to check
///    them; a bottom batch bar pins/unpins or hides/shows all at once, with a
///    live count and All/None.
/// 3. VOICE: record a custom voice for one tile that plays instead of TTS.
///
/// Subcategory FOLDERS stay move-locked (ADR 0014): not draggable, not a
/// drop target, but a doorway (tapping navigates into the sub-board on the
/// session's own stack so the child never observes arrange-mode navigation).
///
/// All edits go through the position overlay (ADR 0014), favourites (ADR 0013),
/// custom buttons (ADR 0012), the hidden-tiles + icon-override + custom-voice
/// overlays (ADR 0019); none mutate a button's identity, so bandit + glow are
/// untouched. The child sees the result only on leaving (Done).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../aac_button_tile.dart';
import '../settings/math_gate.dart';
import '../theme/lighthouse_theme.dart';
import '../tour/first_use_tip.dart';
import '../tour/tour_controller.dart';
import '../widgets/lh_widgets.dart';
import '../widgets/voice_recorder_field.dart';

/// Shows the math gate; on unlock, pushes the editor rooted at the board the
/// parent is currently viewing. Called from the board AppBar.
Future<void> showBoardEditorGate(
  BuildContext context, {
  required String rootBoardId,
}) async {
  final unlocked = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      child: MathGate(onUnlocked: () => Navigator.of(context).pop(true)),
    ),
  );
  if (!context.mounted || unlocked != true) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BoardEditScreen(rootBoardId: rootBoardId),
    ),
  );
}

/// Pure drag-reorder math (ADR 0019), extracted for testing. Given a board, the
/// [dragged] word, and the [dest] slot, returns the set of `buttonId -> new
/// Position` changes to commit (empty = no-op):
/// - dropping onto a FOLDER (move-locked) -> no change;
/// - dropping a word onto an EMPTY non-folder slot -> move it there;
/// - dropping a word onto another WORD -> INSERTION reorder among the board's
///   non-folder slots (words shift, folders keep their slots).
Map<String, Position> computeReorder(
    AACBoard board, AACButton dragged, Position dest) {
  if (dragged.type == AACButtonType.folder) return const {};
  final destBtn = board.buttonAt(dest);
  if (destBtn != null && destBtn.type == AACButtonType.folder) return const {};
  if (destBtn == null) {
    if (board.buttons.firstWhere((b) => b.id == dragged.id).position == dest) {
      return const {};
    }
    return {dragged.id: dest};
  }
  if (destBtn.id == dragged.id) return const {};

  final rows = board.gridDimensions.rows;
  final cols = board.gridDimensions.cols;
  // Non-folder slots in row-major order (folders hold their slots).
  final wordSlots = <Position>[];
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final p = (row: r, col: c);
      final b = board.buttonAt(p);
      if (b == null || b.type != AACButtonType.folder) wordSlots.add(p);
    }
  }
  // Occupied word ids in slot order, with [dragged] removed and re-inserted at
  // the target's position.
  final seq = <String>[
    for (final p in wordSlots)
      if (board.buttonAt(p) case final b? when b.type != AACButtonType.folder)
        b.id,
  ]..remove(dragged.id);
  var insertAt = seq.indexOf(destBtn.id);
  if (insertAt < 0) insertAt = seq.length;
  seq.insert(insertAt, dragged.id);

  final current = {for (final b in board.buttons) b.id: b.position};
  final changed = <String, Position>{};
  for (var i = 0; i < seq.length && i < wordSlots.length; i++) {
    if (current[seq[i]] != wordSlots[i]) changed[seq[i]] = wordSlots[i];
  }
  return changed;
}

enum _EditMode { arrange, select }

class BoardEditScreen extends ConsumerStatefulWidget {
  const BoardEditScreen({required this.rootBoardId, super.key});

  /// The board the session starts on (the one the parent was viewing).
  final String rootBoardId;

  @override
  ConsumerState<BoardEditScreen> createState() => _BoardEditScreenState();
}

class _BoardEditScreenState extends ConsumerState<BoardEditScreen> {
  _EditMode _mode = _EditMode.arrange;

  /// Selected tile ids in select mode.
  final Set<String> _selected = {};

  /// The session's OWN nav stack of board ids (ADR 0014 Amendment 1): folder
  /// doorways push/pop here, not on the child-facing boardStackProvider.
  late final List<String> _stackIds = [widget.rootBoardId];

  /// First-use tip (ADR 0020), anchored to the Select button. Shown once, the
  /// first time a parent opens the editor.
  final GlobalKey _selectKey = GlobalKey();
  late final FirstUseTipController _tipController;

  @override
  void initState() {
    super.initState();
    _tipController = ref.read(firstUseTipControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _tipController.maybeShow(
        context: context,
        store: ref.read(firstUseTipsStoreProvider),
        tipKey: FirstUseTipsStore.editorKey,
        anchor: _selectKey,
        title: l10n.tipEditorTitle,
        body: l10n.tipEditorBody,
        gotItLabel: l10n.tipGotIt,
        tourActive: ref.read(tourControllerProvider).active,
        reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
      );
    });
  }

  @override
  void dispose() {
    _tipController.dismiss(ownerTipKey: FirstUseTipsStore.editorKey);
    super.dispose();
  }

  String get _currentBoardId => _stackIds.last;

  void _enterFolder(String linkId) => setState(() {
        _stackIds.add(linkId);
        _exitSelect();
      });

  void _popBoard() {
    if (_stackIds.length <= 1) return;
    setState(() {
      _stackIds.removeLast();
      _exitSelect();
    });
  }

  void _exitSelect() {
    _mode = _EditMode.arrange;
    _selected.clear();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1800),
        content: Text(message),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final boards = ref.watch(editableBoardsProvider).valueOrNull;
    final board = boards?.where((b) => b.boardId == _currentBoardId).firstOrNull;

    if (board == null) {
      // Never trap the parent on a bare spinner: always offer Done, and a back
      // affordance if we navigated below root into a bad sub-board.
      return Scaffold(
        appBar: lhAppBar(
          context,
          title: l10n.editBoardTitle,
          centerTitle: true,
          leading: _stackIds.length > 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _popBoard,
                )
              : null,
          actions: [
            TextButton(
              key: const ValueKey('editor_done'),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.editDone),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _mode == _EditMode.select
          ? _selectAppBar(l10n, board)
          : _arrangeAppBar(l10n, board),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                  child: Text(
                    _mode == _EditMode.select
                        ? l10n.editSelectHint
                        : l10n.editArrangeHint,
                    style: LhText.rowSubtitle,
                  ),
                ),
                Expanded(
                  child: _EditGrid(
                board: board,
                mode: _mode,
                selected: _selected,
                onTapTile: (btn) => _onTapTile(board, btn),
                onTapEmpty: (pos) => _addAtSlot(board, pos),
                onTapFolder: (btn) {
                  final link = btn.linkId;
                  if (link != null) _enterFolder(link);
                },
                onReorder: (dragged, dest) => _reorder(board, dragged, dest),
              ),
            ),
                if (_mode == _EditMode.select) _batchBar(l10n, board),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- app bars
  PreferredSizeWidget _arrangeAppBar(AppLocalizations l10n, AACBoard board) {
    return lhAppBar(
      context,
      title: board.boardNameFor(Localizations.localeOf(context).languageCode),
      centerTitle: false,
      leading: _stackIds.length > 1
          ? IconButton(
              key: const ValueKey('editor_nav_back'),
              icon: const Icon(Icons.arrow_back),
              onPressed: _popBoard,
            )
          : null,
      actions: [
        IconButton(
          key: const ValueKey('editor_share'),
          tooltip: l10n.editShareBoard,
          icon: const Icon(Icons.ios_share),
          onPressed: () => _shareBoard(board),
        ),
        PopupMenuButton<String>(
          key: const ValueKey('editor_reset_menu'),
          onSelected: (v) {
            if (v == 'board') {
              // "Reset this board": undo EVERY customization on the current
              // board (clinical review: previously only the layout reset, so a hidden
              // tile could never be un-hidden here). Capture the on-board ids
              // before removing custom buttons so their voices clear too.
              _confirmReset(l10n.editResetBoardConfirm, () async {
                final ids = board.buttons.map((b) => b.id).toList();
                await ref
                    .read(customButtonsProvider.notifier)
                    .removeForBoard(board.boardId);
                await ref
                    .read(customVoiceProvider.notifier)
                    .removeMany(ids);
                await ref
                    .read(iconOverridesProvider.notifier)
                    .resetBoard(board.boardId);
                await ref
                    .read(hiddenTilesProvider.notifier)
                    .resetBoard(board.boardId);
                await ref
                    .read(boardLayoutProvider.notifier)
                    .resetBoard(board.boardId);
              });
            } else if (v == 'all') {
              // "Reset everything": same, across every board, back to factory.
              _confirmReset(l10n.editResetAllConfirm, () async {
                await ref.read(customButtonsProvider.notifier).resetAll();
                await ref.read(customVoiceProvider.notifier).resetAll();
                await ref.read(iconOverridesProvider.notifier).resetAll();
                await ref.read(hiddenTilesProvider.notifier).resetAll();
                await ref.read(boardLayoutProvider.notifier).resetAll();
              });
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(value: 'board', child: Text(l10n.editResetBoard)),
            PopupMenuItem(value: 'all', child: Text(l10n.editResetAll)),
          ],
        ),
        KeyedSubtree(
          key: _selectKey,
          child: TextButton(
            key: const ValueKey('editor_select'),
            onPressed: () => setState(() {
              _mode = _EditMode.select;
              _selected.clear();
            }),
            child: Text(l10n.editSelect),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: FilledButton(
            key: const ValueKey('editor_done'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.editDone),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _selectAppBar(AppLocalizations l10n, AACBoard board) {
    final n = _selected.length;
    final all = _selectableIds(board);
    return lhAppBar(
      context,
      centerTitle: true,
      title: n == 0 ? l10n.editSelectTiles : l10n.editSelectedCount(n),
      automaticallyImplyLeading: false,
      // Widen the leading slot so "Cancel" (and longer translations) never wrap.
      leadingWidth: 110,
      leading: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          key: const ValueKey('editor_selcancel'),
          onPressed: () => setState(_exitSelect),
          child: Text(l10n.cancel, maxLines: 1, softWrap: false),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('editor_selall'),
          onPressed: () => setState(() {
            if (_selected.length >= all.length) {
              _selected.clear();
            } else {
              _selected
                ..clear()
                ..addAll(all);
            }
          }),
          child: Text(
              _selected.length >= all.length && all.isNotEmpty
                  ? l10n.editSelectNone
                  : l10n.editSelectAll),
        ),
      ],
    );
  }

  /// Selectable = every non-folder button on the board (folders are locked).
  List<String> _selectableIds(AACBoard board) => [
        for (final b in board.buttons)
          if (b.type != AACButtonType.folder) b.id,
      ];

  // ------------------------------------------------------------- batch bar
  Widget _batchBar(AppLocalizations l10n, AACBoard board) {
    final ids = _selected.toList();
    final n = ids.length;
    final enabled = n > 0;
    final pins = ref.watch(favouritesProvider).valueOrNull ?? const [];
    bool isPinned(String id) =>
        pins.any((r) => r.boardId == board.boardId && r.buttonId == id);
    final allFav = enabled && ids.every(isPinned);
    final hidden = ref.watch(hiddenTilesProvider).valueOrNull ??
        const HiddenTiles.empty();
    final anyVisible = ids.any((id) => !hidden.isHidden(board.boardId, id));

    return Material(
      color: LhColors.surface,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LhColors.line)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
        child: Row(
          children: [
            Text(l10n.editSelectedCount(n), style: LhText.rowTitle),
            const Spacer(),
            FilledButton.tonalIcon(
              key: const ValueKey('editor_bulk_pin'),
              onPressed: enabled
                  ? () => _batchPin(board, ids, unpin: allFav)
                  : null,
              icon: Icon(allFav ? Icons.star : Icons.star_outline),
              label: Text(allFav ? l10n.editActionUnpin : l10n.editActionPin),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('editor_bulk_hide'),
              onPressed: enabled
                  ? () => _batchHide(board, ids, hide: anyVisible)
                  : null,
              icon: Icon(anyVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              label: Text(anyVisible ? l10n.editBatchHide : l10n.editBatchShow),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batchPin(AACBoard board, List<String> ids,
      {required bool unpin}) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(favouritesProvider.notifier);
    final pins = ref.read(favouritesProvider).valueOrNull ?? const [];
    var count = 0;
    if (unpin) {
      for (final id in ids) {
        await notifier.unpin(board.boardId, id);
        count++;
      }
      _toast(l10n.editToastUnpinned(count));
    } else {
      var pinnedNow =
          pins.where((r) => r.boardId == board.boardId).length;
      for (final id in ids) {
        final already =
            pins.any((r) => r.boardId == board.boardId && r.buttonId == id);
        if (already) continue;
        if (pinnedNow >= kMaxFavourites) {
          _toast(l10n.editFavouritesFull(kMaxFavourites));
          break;
        }
        await notifier.pin(board.boardId, id);
        pinnedNow++;
        count++;
      }
      _toast(l10n.editToastPinned(count));
    }
    if (mounted) setState(_exitSelect);
  }

  Future<void> _batchHide(AACBoard board, List<String> ids,
      {required bool hide}) async {
    final l10n = AppLocalizations.of(context);
    await ref
        .read(hiddenTilesProvider.notifier)
        .setHiddenBulk(board.boardId, ids, hide);
    _toast(hide
        ? l10n.editToastHidden(ids.length)
        : l10n.editToastShown(ids.length));
    if (mounted) setState(_exitSelect);
  }

  // ---------------------------------------------------------- tile tapping
  void _onTapTile(AACBoard board, AACButton btn) {
    if (_mode == _EditMode.select) {
      setState(() {
        if (_selected.contains(btn.id)) {
          _selected.remove(btn.id);
        } else {
          _selected.add(btn.id);
        }
      });
      return;
    }
    _openQuickActions(board, btn);
  }

  // ----------------------------------------------------- quick-action sheet
  Future<void> _openQuickActions(AACBoard board, AACButton btn) async {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final pins = ref.read(favouritesProvider).valueOrNull ?? const [];
    final isPinned =
        pins.any((r) => r.boardId == board.boardId && r.buttonId == btn.id);
    final hidden = ref.read(hiddenTilesProvider).valueOrNull ??
        const HiddenTiles.empty();
    final isHidden = hidden.isHidden(board.boardId, btn.id);
    final hasVoice =
        (ref.read(customVoiceProvider).valueOrNull ?? const {}).containsKey(btn.id);
    final isCustom = btn.category == kCustomCategory;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: LhColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LhRadii.dialog)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHeader(
                button: btn,
                colorKey: board.colorKey,
                title: btn.labelFor(lang),
                subtitle: l10n.editTileSheetSubtitle,
              ),
              const Divider(height: 1, color: LhColors.line),
              const SizedBox(height: 6),
              _SheetAction(
                icon: Icons.mic_none_rounded,
                iconColor: LhColors.brown,
                title: hasVoice
                    ? l10n.editActionRerecordVoice
                    : l10n.editActionRecordVoice,
                subtitle: hasVoice
                    ? l10n.editActionVoiceSetSub
                    : l10n.editActionRecordVoiceSub,
                onTap: () => Navigator.of(sheetContext).pop('voice'),
              ),
              _SheetAction(
                icon: Icons.image_outlined,
                title: l10n.editActionReplacePicture,
                subtitle: l10n.editActionReplacePictureSub,
                onTap: () => Navigator.of(sheetContext).pop('picture'),
              ),
              _SheetAction(
                icon: isPinned ? Icons.star_rounded : Icons.star_outline_rounded,
                title: isPinned ? l10n.editActionUnpin : l10n.editActionPin,
                subtitle: l10n.editActionPinSub,
                onTap: () =>
                    Navigator.of(sheetContext).pop(isPinned ? 'unpin' : 'pin'),
              ),
              _SheetAction(
                icon: isHidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                title: isHidden ? l10n.editActionShow : l10n.editActionHide,
                subtitle:
                    isHidden ? l10n.editActionShowSub : l10n.editActionHideSub,
                onTap: () =>
                    Navigator.of(sheetContext).pop(isHidden ? 'show' : 'hide'),
              ),
              if (isCustom)
                _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  iconColor: LhColors.amberDeep,
                  title: l10n.customButtonsDelete,
                  subtitle: null,
                  onTap: () => Navigator.of(sheetContext).pop('delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'voice':
        await _openVoiceSheet(board, btn);
      case 'picture':
        await _replacePicture(board, btn);
      case 'pin':
        _pin(board.boardId, btn.id);
        _toast(l10n.editToastPinnedOne);
      case 'unpin':
        _unpin(board.boardId, btn.id);
        _toast(l10n.editToastUnpinnedOne);
      case 'hide':
        await ref
            .read(hiddenTilesProvider.notifier)
            .setHidden(board.boardId, btn.id, true);
        _toast(l10n.editToastHiddenOne);
      case 'show':
        await ref
            .read(hiddenTilesProvider.notifier)
            .setHidden(board.boardId, btn.id, false);
        _toast(l10n.editToastShownOne);
      case 'delete':
        await ref.read(customButtonsProvider.notifier).remove(btn.id);
    }
  }

  Future<void> _replacePicture(AACBoard board, AACButton btn) async {
    final l10n = AppLocalizations.of(context);
    // System photo picker (PHPicker on iOS 14+, Android photo picker): no
    // Photos permission prompt and no usage string (ADR 0016).
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    final path = picked?.path;
    if (path == null || !mounted) return;
    final file = File(path);
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot).toLowerCase();
    final tooBig = await file.length() > CustomButtonStore.maxImageBytes;
    if (!mounted) return;
    if (tooBig || !CustomButtonStore.allowedImageExtensions.contains(ext)) {
      _toast(l10n.imageRejected);
      return;
    }
    try {
      await ref
          .read(iconOverridesProvider.notifier)
          .setImage(board.boardId, btn.id, file);
      if (mounted) _toast(l10n.editToastPictureReplaced);
    } on IconOverrideException {
      if (mounted) _toast(l10n.imageRejected);
    }
  }

  Future<void> _openVoiceSheet(AACBoard board, AACButton btn) async {
    final lang = Localizations.localeOf(context).languageCode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LhColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LhRadii.dialog)),
      ),
      builder: (_) => _VoiceRecordingSheet(
        button: btn,
        colorKey: board.colorKey,
        word: btn.labelFor(lang),
      ),
    );
  }

  // ------------------------------------------------------------- favourites
  void _pin(String boardId, String buttonId) {
    final l10n = AppLocalizations.of(context);
    final pins = ref.read(favouritesProvider).valueOrNull ?? const [];
    final already =
        pins.any((r) => r.boardId == boardId && r.buttonId == buttonId);
    if (!already && pins.length >= kMaxFavourites) {
      _toast(l10n.editFavouritesFull(kMaxFavourites));
      return;
    }
    ref.read(favouritesProvider.notifier).pin(boardId, buttonId);
  }

  void _unpin(String boardId, String buttonId) =>
      ref.read(favouritesProvider.notifier).unpin(boardId, buttonId);

  // -------------------------------------------------------------- reorder
  /// Drag-reorder commit (ADR 0019). Dropping a word onto another word does an
  /// INSERTION reorder among the board's non-folder slots (words shift, folders
  /// stay put); dropping on an empty slot moves it there; dropping on a folder
  /// is a no-op (folders are move-locked).
  void _reorder(AACBoard board, AACButton dragged, Position dest) {
    final changed = computeReorder(board, dragged, dest);
    if (changed.isNotEmpty) {
      ref.read(boardLayoutProvider.notifier).setPositions(board.boardId, changed);
    }
  }

  // ---------------------------------------------------------------- add
  Future<void> _addAtSlot(AACBoard board, Position pos) async {
    if (_mode == _EditMode.select) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _AddAtSlotDialog(boardId: board.boardId, slot: pos),
    );
  }

  // -------------------------------------------------------------- reset
  Future<void> _confirmReset(
      String body, Future<void> Function() onConfirm) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('editor_reset_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.editResetConfirmButton),
          ),
        ],
      ),
    );
    if (ok == true) await onConfirm();
  }

  // -------------------------------------------------------------- share
  Future<void> _shareBoard(AACBoard board) async {
    final l10n = AppLocalizations.of(context);
    final preview = BoardPackExporter.buildExportBoard(board);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shareVocabTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shareVocabBody),
            if (preview.photosAsTextOnly > 0) ...[
              const SizedBox(height: 12),
              Text(l10n.shareVocabPhotos(preview.photosAsTextOnly)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('editor_share_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.shareVocabConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final languageCode = Localizations.localeOf(context).languageCode;
    File? tempFile;
    try {
      final export = await BoardPackExporter().prepare(board);
      tempFile = export.file;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(export.file.path)],
          subject: board.boardNameFor(languageCode),
        ),
      );
    } catch (_) {
      if (mounted) _toast(l10n.shareVocabFailed);
    } finally {
      if (tempFile != null && tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {/* best-effort */}
      }
    }
  }
}

// ============================================================ editor grid
class _EditGrid extends ConsumerWidget {
  const _EditGrid({
    required this.board,
    required this.mode,
    required this.selected,
    required this.onTapTile,
    required this.onTapEmpty,
    required this.onTapFolder,
    required this.onReorder,
  });

  final AACBoard board;
  final _EditMode mode;
  final Set<String> selected;
  final ValueChanged<AACButton> onTapTile;
  final ValueChanged<Position> onTapEmpty;
  final ValueChanged<AACButton> onTapFolder;
  final void Function(AACButton dragged, Position dest) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = board.gridDimensions.rows;
    final cols = board.gridDimensions.cols;
    final pins = ref.watch(favouritesProvider).valueOrNull ?? const [];
    final hidden =
        ref.watch(hiddenTilesProvider).valueOrNull ?? const HiddenTiles.empty();
    final voices = ref.watch(customVoiceProvider).valueOrNull ?? const {};
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / cols;
        final cellH = constraints.maxHeight / rows;
        final aspect = cellH == 0 ? 1.0 : cellW / cellH;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: aspect,
          ),
          itemCount: rows * cols,
          itemBuilder: (context, index) {
            final pos = (row: index ~/ cols, col: index % cols);
            final btn = board.buttonAt(pos);
            return _Cell(
              board: board,
              pos: pos,
              button: btn,
              mode: mode,
              isSelected: btn != null && selected.contains(btn.id),
              isFavourite: btn != null &&
                  pins.any((r) =>
                      r.boardId == board.boardId && r.buttonId == btn.id),
              isHidden: btn != null && hidden.isHidden(board.boardId, btn.id),
              hasVoice: btn != null && voices.containsKey(btn.id),
              reduceMotion: reduceMotion,
              onTapTile: onTapTile,
              onTapEmpty: onTapEmpty,
              onTapFolder: onTapFolder,
              onReorder: onReorder,
            );
          },
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.board,
    required this.pos,
    required this.button,
    required this.mode,
    required this.isSelected,
    required this.isFavourite,
    required this.isHidden,
    required this.hasVoice,
    required this.reduceMotion,
    required this.onTapTile,
    required this.onTapEmpty,
    required this.onTapFolder,
    required this.onReorder,
  });

  final AACBoard board;
  final Position pos;
  final AACButton? button;
  final _EditMode mode;
  final bool isSelected;
  final bool isFavourite;
  final bool isHidden;
  final bool hasVoice;
  final bool reduceMotion;
  final ValueChanged<AACButton> onTapTile;
  final ValueChanged<Position> onTapEmpty;
  final ValueChanged<AACButton> onTapFolder;
  final void Function(AACButton dragged, Position dest) onReorder;

  bool get _isFolder => button?.type == AACButtonType.folder;

  @override
  Widget build(BuildContext context) {
    final btn = button;
    // Empty slot: a dotted add affordance (arrange) and a word drop target.
    if (btn == null) {
      return DragTarget<AACButton>(
        onWillAcceptWithDetails: (_) => mode == _EditMode.arrange,
        onAcceptWithDetails: (d) => onReorder(d.data, pos),
        builder: (context, candidate, _) => Padding(
          padding: const EdgeInsets.all(7),
          child: GestureDetector(
            key: ValueKey('editor_empty_${pos.row}_${pos.col}'),
            behavior: HitTestBehavior.opaque,
            onTap: mode == _EditMode.arrange ? () => onTapEmpty(pos) : null,
            child: _AddSlot(active: candidate.isNotEmpty),
          ),
        ),
      );
    }

    final visual = _TileVisual(
      button: btn,
      colorKey: board.colorKey,
      isSelected: isSelected,
      isFavourite: isFavourite,
      isHidden: isHidden,
      hasVoice: hasVoice,
      selectMode: mode == _EditMode.select,
      isFolderLocked: _isFolder,
    );

    // Folder: move-locked doorway. Tappable (navigate / cannot select), never
    // a drag source, and it rejects drops (a word cannot displace a folder).
    if (_isFolder) {
      return DragTarget<AACButton>(
        onWillAcceptWithDetails: (_) => false,
        builder: (context, _, __) => Padding(
          padding: const EdgeInsets.all(7),
          child: GestureDetector(
            key: ValueKey('editor_folder_${btn.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: mode == _EditMode.arrange ? () => onTapFolder(btn) : null,
            child: visual,
          ),
        ),
      );
    }

    final tappable = GestureDetector(
      key: ValueKey('editor_tile_${btn.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onTapTile(btn),
      child: visual,
    );

    final cell = Padding(
      padding: const EdgeInsets.all(7),
      child: mode == _EditMode.arrange
          ? _Jiggle(enabled: !reduceMotion, seed: pos.row * 8 + pos.col, child: tappable)
          : tappable,
    );

    return DragTarget<AACButton>(
      onWillAcceptWithDetails: (d) =>
          mode == _EditMode.arrange && d.data.id != btn.id,
      onAcceptWithDetails: (d) => onReorder(d.data, pos),
      builder: (context, candidate, _) {
        final highlighted = candidate.isNotEmpty;
        final body = mode == _EditMode.arrange
            ? LongPressDraggable<AACButton>(
                data: btn,
                feedback: _DragFeedback(button: btn, colorKey: board.colorKey),
                childWhenDragging: Opacity(opacity: 0.18, child: cell),
                child: cell,
              )
            : cell;
        if (!highlighted) return body;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: LhRadii.tileR,
            border: Border.all(color: LhColors.amber, width: 3),
          ),
          child: body,
        );
      },
    );
  }
}

/// One editor tile: the standard tile visual plus badges (favourite / voice /
/// hidden), an optional selection circle, a lock chip on folders, and a greyed
/// look when hidden. The underlying [AACButtonTile] is pointer-ignored so the
/// wrapping gesture owns tap/long-press.
class _TileVisual extends StatelessWidget {
  const _TileVisual({
    required this.button,
    required this.colorKey,
    required this.isSelected,
    required this.isFavourite,
    required this.isHidden,
    required this.hasVoice,
    required this.selectMode,
    required this.isFolderLocked,
  });

  final AACButton button;
  final Map<String, String> colorKey;
  final bool isSelected;
  final bool isFavourite;
  final bool isHidden;
  final bool hasVoice;
  final bool selectMode;
  final bool isFolderLocked;

  @override
  Widget build(BuildContext context) {
    final tile = IgnorePointer(
      child: AACButtonTile(button: button, colorKey: colorKey, onTap: () {}),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(opacity: isHidden ? 0.45 : 1.0, child: tile),
        ),
        if (isSelected)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: LhRadii.tileR,
                  color: LhColors.brown.withValues(alpha: .10),
                  border: Border.all(color: LhColors.brown, width: 3),
                ),
              ),
            ),
          ),
        // Badges, top-start.
        PositionedDirectional(
          top: 6,
          start: 6,
          child: IgnorePointer(
            child: Row(
              children: [
                if (isFavourite)
                  const _Badge(
                      icon: Icons.star_rounded, color: LhColors.amber),
                if (hasVoice)
                  const _Badge(icon: Icons.mic_rounded, color: LhColors.brown),
                if (isHidden)
                  const _Badge(
                      icon: Icons.visibility_off_rounded,
                      color: Color(0xFF6E655B)),
              ],
            ),
          ),
        ),
        if (isFolderLocked)
          const PositionedDirectional(
            top: 6,
            end: 6,
            child: IgnorePointer(
              child: Icon(Icons.lock_rounded, size: 16, color: LhColors.ink3),
            ),
          ),
        if (selectMode && !isFolderLocked)
          PositionedDirectional(
            top: 6,
            end: 6,
            child: IgnorePointer(child: _SelectMark(selected: isSelected)),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 4),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        boxShadow: [
          BoxShadow(color: LhColors.inkAlpha(.18), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? LhColors.brown : Colors.white.withValues(alpha: .85),
        border: Border.all(color: LhColors.brown, width: 2),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
          : null,
    );
  }
}

/// A gentle continuous iOS-style jiggle (reduced-motion gated). [seed] varies
/// the phase/period per tile so the grid does not jiggle in lockstep.
class _Jiggle extends StatefulWidget {
  const _Jiggle({required this.enabled, required this.seed, required this.child});
  final bool enabled;
  final int seed;
  final Widget child;
  @override
  State<_Jiggle> createState() => _JiggleState();
}

class _JiggleState extends State<_Jiggle> with SingleTickerProviderStateMixin {
  // Created ONLY when enabled. A `late final` initialized inline would lazily
  // construct (and createTicker on) a deactivated element if `dispose` were the
  // first access (the reduced-motion path never touches it in build), which
  // crashes. So keep it nullable and create it eagerly only when animating.
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _startController();
  }

  void _startController() {
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300 + (widget.seed % 3) * 50),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Jiggle old) {
    super.didUpdateWidget(old);
    if (widget.enabled && _c == null) {
      _startController();
    } else if (!widget.enabled && _c != null) {
      _c!.dispose();
      _c = null;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    // -0.9deg .. +0.9deg in radians.
    final tween = Tween<double>(begin: -0.0157, end: 0.0157);
    return AnimatedBuilder(
      animation: c,
      child: widget.child,
      builder: (context, child) =>
          Transform.rotate(angle: tween.evaluate(c), child: child),
    );
  }
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    return DottedAddSlot(active: active);
  }
}

/// Visual placeholder for an empty, droppable slot.
class DottedAddSlot extends StatelessWidget {
  const DottedAddSlot({required this.active, super.key});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active
            ? LhColors.amberTint
            : LhColors.cream2.withValues(alpha: 0.5),
        borderRadius: LhRadii.tileR,
        border: Border.all(
          color: active ? LhColors.amber : LhColors.line2,
          width: 1.5,
        ),
      ),
      child: Icon(Icons.add_rounded,
          color: active ? LhColors.amberDeep : LhColors.ink3),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.button, required this.colorKey});

  final AACButton button;
  final Map<String, String> colorKey;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 104,
        height: 104,
        child: Transform.scale(
          scale: 1.06,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: LhRadii.tileR,
              boxShadow: LhShadows.pop,
            ),
            child: AACButtonTile(
              button: button,
              colorKey: colorKey,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================== quick-action sheet bits
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.button,
    required this.colorKey,
    required this.title,
    required this.subtitle,
  });

  final AACButton button;
  final Map<String, String> colorKey;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: IgnorePointer(
              child: AACButtonTile(
                  button: button, colorKey: colorKey, onTap: () {}),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: LhText.rowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: LhText.rowSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = LhColors.ink2,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 34, child: Icon(icon, size: 28, color: iconColor)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: LhText.rowTitle.copyWith(fontSize: 19)),
                  if (subtitle != null)
                    Text(subtitle!, style: LhText.rowSubtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================== voice recording sheet
class _VoiceRecordingSheet extends ConsumerStatefulWidget {
  const _VoiceRecordingSheet({
    required this.button,
    required this.colorKey,
    required this.word,
  });

  final AACButton button;
  final Map<String, String> colorKey;
  final String word;

  @override
  ConsumerState<_VoiceRecordingSheet> createState() =>
      _VoiceRecordingSheetState();
}

enum _VoicePhase { idle, recording, review, saved }

class _VoiceRecordingSheetState extends ConsumerState<_VoiceRecordingSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  late _VoicePhase _phase;
  Timer? _timer;
  int _secs = 0;
  String? _tempPath; // freshly recorded clip awaiting Save
  bool _busy = false;

  static const int _maxSecs = 15;

  @override
  void initState() {
    super.initState();
    final has = (ref.read(customVoiceProvider).valueOrNull ?? const {})
        .containsKey(widget.button.id);
    _phase = has ? _VoicePhase.saved : _VoicePhase.idle;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context);
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.editVoiceMicDenied)),
        );
      }
      return;
    }
    final dir = Directory.systemTemp;
    final path =
        '${dir.path}/lh_voice_${widget.button.id}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _phase = _VoicePhase.recording;
      _secs = 0;
      _tempPath = path;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secs += 1);
      if (_secs >= _maxSecs) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _tempPath = path ?? _tempPath;
      _phase = _VoicePhase.review;
    });
  }

  Future<void> _play(String path) async {
    await ref.read(customVoicePlayerProvider).play(path);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final path = _tempPath;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(customVoiceProvider.notifier)
          .save(widget.button.id, File(path));
      if (!mounted) return;
      setState(() {
        _phase = _VoicePhase.saved;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.editToastVoiceSaved)),
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    await ref.read(customVoiceProvider.notifier).remove(widget.button.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.editToastVoiceDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            22, 0, 22, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              button: widget.button,
              colorKey: widget.colorKey,
              title: l10n.editVoiceTitle(widget.word),
              subtitle: l10n.editVoiceOverrideSub,
            ),
            const Divider(height: 1, color: LhColors.line),
            const SizedBox(height: 18),
            ..._body(l10n, lang, reduceMotion),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(AppLocalizations l10n, String lang, bool reduceMotion) {
    switch (_phase) {
      case _VoicePhase.idle:
        return [
          Text(l10n.editVoicePrompt(widget.word),
              textAlign: TextAlign.center, style: LhText.body),
          const SizedBox(height: 18),
          _Waveform(active: false, reduceMotion: reduceMotion),
          const SizedBox(height: 18),
          _RecordButton(recording: false, onTap: _startRecording),
          const SizedBox(height: 10),
          Text(l10n.editVoiceTapToRecord, style: LhText.rowSubtitle),
        ];
      case _VoicePhase.recording:
        return [
          Text(l10n.editVoiceListening(widget.word),
              textAlign: TextAlign.center, style: LhText.body),
          const SizedBox(height: 18),
          _Waveform(active: true, reduceMotion: reduceMotion),
          const SizedBox(height: 18),
          _RecordButton(recording: true, onTap: _stopRecording),
          const SizedBox(height: 10),
          Text('0:${_secs.toString().padLeft(2, '0')}  ${l10n.editVoiceTapToStop}',
              style: LhText.rowSubtitle),
        ];
      case _VoicePhase.review:
        return [
          Text(l10n.editVoiceReview(widget.word),
              textAlign: TextAlign.center, style: LhText.body),
          const SizedBox(height: 18),
          _Waveform(active: false, reduceMotion: reduceMotion),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _tempPath == null ? null : () => _play(_tempPath!),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.editVoicePlay),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.editVoiceRerecord),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.editVoiceUseRecording),
            ),
          ),
        ];
      case _VoicePhase.saved:
        final path =
            (ref.watch(customVoiceProvider).valueOrNull ?? const {})[widget.button.id];
        return [
          const SizedBox(
            width: 76,
            height: 76,
            child: DecoratedBox(
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: LhColors.goodBg),
              child: Icon(Icons.check_rounded, size: 42, color: LhColors.good),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.editVoiceSavedMsg(widget.word),
              textAlign: TextAlign.center, style: LhText.body),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: path == null ? null : () => _play(path),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.editVoicePlay),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _startRecording,
                  icon: const Icon(Icons.mic_none_rounded),
                  label: Text(l10n.editVoiceRerecord),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: LhColors.amberDeep,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l10n.editVoiceDelete),
            ),
          ),
        ];
    }
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onTap});
  final bool recording;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: recording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? const Color(0xFFB23B2E) : LhColors.brown,
            boxShadow: LhShadows.primaryButton,
          ),
          child: Icon(
            recording ? Icons.stop_rounded : Icons.mic_rounded,
            size: 42,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Decorative waveform (matches the prototype: not real amplitude). Animates
/// only while recording and only when motion is allowed.
class _Waveform extends StatefulWidget {
  const _Waveform({required this.active, required this.reduceMotion});
  final bool active;
  final bool reduceMotion;
  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _maybeRun();
  }

  @override
  void didUpdateWidget(_Waveform old) {
    super.didUpdateWidget(old);
    _maybeRun();
  }

  void _maybeRun() {
    final run = widget.active && !widget.reduceMotion;
    if (run && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const n = 28;
    final color = widget.active ? LhColors.amber : LhColors.line2;
    return SizedBox(
      height: 64,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < n; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 5,
                  height: widget.active
                      ? 10 + ((i % 7) * 7) * (0.4 + 0.6 * _c.value)
                      : 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================= add-at-slot
/// Targeted add: drop a new custom button into the specific [slot] the parent
/// tapped (the visual-placement flow, ADR 0014). Mirrors the custom-buttons add
/// dialog but with a fixed board + slot.
class _AddAtSlotDialog extends ConsumerStatefulWidget {
  const _AddAtSlotDialog({required this.boardId, required this.slot});

  final String boardId;
  final Position slot;

  @override
  ConsumerState<_AddAtSlotDialog> createState() => _AddAtSlotDialogState();
}

class _AddAtSlotDialogState extends ConsumerState<_AddAtSlotDialog> {
  final _wordController = TextEditingController();
  final _voiceController = VoiceRecorderController();
  File? _image;
  File? _voiceClip;
  bool _saving = false;

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    final path = picked?.path;
    if (path == null) return;
    final file = File(path);
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot).toLowerCase();
    final tooBig = await file.length() > CustomButtonStore.maxImageBytes;
    if (!mounted) return;
    if (tooBig || !CustomButtonStore.allowedImageExtensions.contains(ext)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.imageRejected)));
      return;
    }
    setState(() => _image = file);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final word = _wordController.text.trim();
    if (word.isEmpty) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(customButtonsProvider.notifier).addButton(
            boardId: widget.boardId,
            row: widget.slot.row,
            col: widget.slot.col,
            label: word,
            imageSource: _image,
          );
      // Attach the optional recorded voice to the brand-new button (ADR 0019).
      // Finalize first so a recording the parent never tapped Stop on is still
      // captured, instead of being silently dropped.
      final clip = await _voiceController.finalize() ?? _voiceClip;
      if (clip != null) {
        await ref.read(customVoiceProvider.notifier).save(id, clip);
      }
    } on CustomButtonImageException {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.imageRejected)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = !_saving && _wordController.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(l10n.editActionAddHere),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _wordController,
              decoration:
                  InputDecoration(labelText: l10n.customButtonsWordLabel),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_image != null) ...[
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Image.file(_image!, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l10n.customButtonsChoosePhoto),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Optional: record your own voice for this tile at creation time
            // (clinical review). Saved against the new button's id after Save.
            VoiceRecorderField(
              idHint: widget.boardId,
              controller: _voiceController,
              onChanged: (f) => _voiceClip = f,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          child: Text(l10n.customButtonsSave),
        ),
      ],
    );
  }
}
