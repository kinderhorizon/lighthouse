/// Parent custom-button editor (ADR 0012).
///
/// Lists the parent-authored buttons (with delete) and offers an add flow:
/// pick a board, optionally pick a photo, type the word. The new button is
/// placed in the board's first empty slot. Reached only through the math gate.
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
                        onDelete: () => ref
                            .read(customButtonsProvider.notifier)
                            .remove(b.id),
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
}

class _CustomButtonRow extends StatelessWidget {
  const _CustomButtonRow({
    required this.button,
    required this.boardName,
    required this.onDelete,
  });

  final CustomButton button;
  final String boardName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 44,
        child: button.imagePath.isEmpty
            ? const Icon(Icons.label_outline)
            : Image.file(
                File(button.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
      ),
      title: Text(button.label),
      subtitle: Text(boardName),
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
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final boards = ref.watch(editableBoardsProvider).valueOrNull ?? const [];
    // Only boards with a free slot can host a new button.
    final placeable =
        boards.where((b) => b.emptySlots(limit: 1).isNotEmpty).toList();

    final selected = _boardId == null
        ? null
        : boards.where((b) => b.boardId == _boardId).firstOrNull;
    final canSave = !_saving &&
        selected != null &&
        _wordController.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text(l10n.customButtonsAdd),
      content: SingleChildScrollView(
        child: Column(
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
              onChanged: (v) => setState(() => _boardId = v),
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
