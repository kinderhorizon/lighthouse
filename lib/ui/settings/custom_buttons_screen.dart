/// Parent custom-button editor (ADR 0012, ADR 0022).
///
/// Lists the parent-authored buttons and categories (with delete) and offers
/// an add flow: pick a board, optionally pick a photo, type the word, choose a
/// colour. The new button is placed in the board's first empty slot. (Choosing
/// the exact square, adding a category, or adding to a full page happens in the
/// board editor, where the parent can see the page.) Reached only through the
/// math gate.
library;

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../tour/first_use_tip.dart';
import '../widgets/lh_widgets.dart';
import '../widgets/tile_color_picker.dart';
import '../widgets/voice_recorder_field.dart';

class CustomButtonsScreen extends ConsumerWidget {
  const CustomButtonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final customsAsync = ref.watch(customButtonsProvider);
    // Board id -> localized display name, for the row subtitles.
    final boards = ref.watch(editableBoardsProvider).valueOrNull ?? const [];
    final lang = Localizations.localeOf(context).languageCode;
    final nameById = {for (final b in boards) b.boardId: b.boardNameFor(lang)};
    final customs = customsAsync.valueOrNull ?? const [];

    // First-use tip anchored to the add control (ADR 0020).
    return FirstUseTipHost(
      tipKey: FirstUseTipsStore.customButtonsKey,
      title: l10n.tipButtonsTitle,
      body: l10n.tipButtonsBody,
      builder: (context, anchorKey) => Scaffold(
        appBar: lhAppBar(context, title: l10n.customButtonsTitle),
        // FAB only once buttons exist; the empty state offers its own primary
        // action (handoff).
        floatingActionButton: customs.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openAdd(context),
                backgroundColor: LhColors.brown,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: Text(l10n.customButtonsAdd),
              ),
        body: SafeArea(
          child: customsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) => list.isEmpty
                ? LhEmptyState(
                    icon: Icons.add_photo_alternate_outlined,
                    headline: l10n.customButtonsEmptyHeadline,
                    body: l10n.customButtonsEmptyBody,
                    action: KeyedSubtree(
                      key: anchorKey,
                      child: FilledButton.icon(
                        onPressed: () => _openAdd(context),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.customButtonsAddFirst),
                      ),
                    ),
                  )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                  children: [
                    for (final b in list)
                      _CustomButtonRow(
                        button: b,
                        boardName: nameById[b.boardId] ?? b.boardId,
                        // "in place of" subtitle (ADR 0022): the replaced word
                        // is set aside, so read it from the registry board.
                        replacedLabel: b.replacesId == null
                            ? null
                            : ref
                                .watch(builtInButtonProvider((
                                  boardId: b.boardId,
                                  buttonId: b.replacesId!,
                                )))
                                .valueOrNull
                                ?.labelFor(lang),
                        onDelete: () => _delete(context, ref, b),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAdd(BuildContext context) => showDialog<void>(
        context: context,
        builder: (_) => const _AddCustomButtonDialog(),
      );

  /// Deletes [b]. A category asks first: its page and everything on it go too
  /// (ADR 0022).
  Future<void> _delete(
      BuildContext context, WidgetRef ref, CustomButton b) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(customButtonsProvider.notifier);
    if (b.isCategory) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(
              l10n.deleteCategoryConfirm(b.label, notifier.buttonsInside(b.id))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const ValueKey('custom_delete_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.deleteConfirm),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await notifier.remove(b.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.customTileSaveFailed)));
    }
  }
}

class _CustomButtonRow extends StatelessWidget {
  const _CustomButtonRow({
    required this.button,
    required this.boardName,
    required this.replacedLabel,
    required this.onDelete,
  });

  final CustomButton button;
  final String boardName;

  /// The built-in word this button takes the place of, if any (ADR 0022).
  final String? replacedLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fill = tileColorFill(button.tileColor);
    final String subtitle;
    if (button.isCategory) {
      subtitle = l10n.customButtonsCategoryOn(boardName);
    } else if (replacedLabel != null) {
      subtitle = l10n.customButtonsInPlaceOf(boardName, replacedLabel!);
    } else {
      subtitle = boardName;
    }
    return ListTile(
      // The tile's own colour behind its photo or icon, so the list matches
      // the board.
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        clipBehavior: Clip.antiAlias,
        child: button.imagePath.isEmpty
            ? Icon(button.isCategory
                ? Icons.folder_outlined
                : Icons.label_outline)
            : Image.file(
                File(button.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
      ),
      title: Text(button.label),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.customButtonsDelete,
        onPressed: onDelete,
      ),
    );
  }
}

class _AddCustomButtonDialog extends ConsumerStatefulWidget {
  const _AddCustomButtonDialog();

  @override
  ConsumerState<_AddCustomButtonDialog> createState() =>
      _AddCustomButtonDialogState();
}

class _AddCustomButtonDialogState
    extends ConsumerState<_AddCustomButtonDialog> {
  final _wordController = TextEditingController();
  final _voiceController = VoiceRecorderController();
  String? _boardId;
  File? _image;
  File? _voiceClip;
  bool _saving = false;

  /// Chosen colour (ADR 0022). Follows the chosen board's own colour until the
  /// parent picks one themselves.
  TileColor? _color;
  bool _colorChosen = false;

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    // System photo picker (PHPicker on iOS 14+, Android photo picker): no
    // Photos permission prompt and no usage string (ADR 0016).
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    final path = picked?.path;
    if (path == null) return;
    final file = File(path);
    // Reject an oversized or non-image file immediately, so the parent gets
    // feedback now and we never copy a huge photo into app storage (the store
    // enforces the same caps as a backstop).
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

  Future<void> _save(List<AACBoard> boards) async {
    final l10n = AppLocalizations.of(context);
    final boardId = _boardId;
    final word = _wordController.text.trim();
    if (boardId == null || word.isEmpty) return;
    final board = boards.firstWhere((b) => b.boardId == boardId);
    final slot = board.emptySlots(limit: 1);
    if (slot.isEmpty) return;

    setState(() => _saving = true);
    try {
      final id = await ref.read(customButtonsProvider.notifier).addButton(
            boardId: boardId,
            row: slot.first.row,
            col: slot.first.col,
            label: word,
            imageSource: _image,
            tileColor: _color,
          );
      // Attach the optional recorded voice to the brand-new button (ADR 0019).
      // Finalize first so a recording the parent never tapped Stop on is still
      // captured, instead of being silently dropped.
      final clip = await _voiceController.finalize() ?? _voiceClip;
      if (clip != null) {
        await ref.read(customVoiceProvider.notifier).save(id, clip);
      }
    } on CustomButtonImageException {
      // Backstop if a too-large/unsupported image slipped past _pickImage.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.imageRejected)));
      return;
    } catch (_) {
      // Includes a whole-file-corrupt store refusing to overwrite (item 7): the
      // parent's existing buttons are preserved. Never leave the spinner stuck.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.customTileSaveFailed)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final boards = ref.watch(editableBoardsProvider).valueOrNull ?? const [];
    // Only boards with a free slot can host a new button. The chosen board
    // stays listed even once full: saving into its LAST free slot rebuilds this
    // dialog before it closes, and the dropdown must still hold its value.
    final placeable = boards
        .where((b) =>
            b.emptySlots(limit: 1).isNotEmpty || b.boardId == _boardId)
        .toList();

    final selected = _boardId == null
        ? null
        : boards.where((b) => b.boardId == _boardId).firstOrNull;
    final canSave = !_saving &&
        selected != null &&
        _wordController.text.trim().isNotEmpty;

    // The title scrolls with the content so a small phone with the keyboard
    // open only has to fit the Cancel / Save row.
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.customButtonsAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _boardId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.customButtonsBoardLabel),
            items: [
              for (final b in placeable)
                DropdownMenuItem(
                  value: b.boardId,
                  child: Text(
                    '${b.boardNameFor(lang)} '
                    '(${b.emptySlots().length})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() {
              _boardId = v;
              if (!_colorChosen) {
                final board = boards.where((b) => b.boardId == v).firstOrNull;
                final customs =
                    ref.read(customButtonsProvider).valueOrNull ?? const [];
                _color = board == null
                    ? null
                    : defaultTileColorFor(board, customs);
              }
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _wordController,
            decoration: InputDecoration(labelText: l10n.customButtonsWordLabel),
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
          const SizedBox(height: 16),
          TileColorPicker(
            value: _color,
            onChanged: (c) => setState(() {
              _color = c;
              _colorChosen = true;
            }),
          ),
          const SizedBox(height: 12),
          // Optional: record your own voice for this tile at creation time
          // (clinical review). Saved against the new button's id after Save.
          VoiceRecorderField(
            idHint: _boardId ?? 'tile',
            controller: _voiceController,
            onChanged: (f) => _voiceClip = f,
          ),
          if (placeable.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.customButtonsNoFreeSlots,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: canSave ? () => _save(boards) : null,
          child: Text(l10n.customButtonsSave),
        ),
      ],
    );
  }
}
