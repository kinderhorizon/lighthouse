/// Add or edit a parent-made tile (ADR 0022).
///
/// One dialog for every way a parent makes or changes their own tile, so they
/// all look and behave the same:
/// - add a BUTTON or a CATEGORY (a folder with its own blank page) in an empty
///   square;
/// - add one IN PLACE OF a built-in word (the word is set aside, not deleted,
///   and comes back if the new tile is deleted);
/// - EDIT one of their own tiles: word or name, photo, colour.
///
/// The colour starts on the page's own colour (the category's colour on a
/// parent-made page, the group colour on Food / People / ..., grey on Home).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../widgets/tile_color_picker.dart';
import '../widgets/voice_recorder_field.dart';

class CustomTileDialog extends ConsumerStatefulWidget {
  /// Add a new button or category on [boardId] at the DISPLAYED [slot]. With
  /// [replacing], the new tile goes in place of that built-in word (whose slot
  /// [slot] must be).
  const CustomTileDialog.add({
    required String this.boardId,
    required Position this.slot,
    this.replacing,
    this.initialColor,
    super.key,
  }) : existing = null;

  /// Edit the parent-made tile [existing].
  const CustomTileDialog.edit({
    required CustomButton this.existing,
    super.key,
  })  : boardId = null,
        slot = null,
        replacing = null,
        initialColor = null;

  final String? boardId;
  final Position? slot;
  final AACButton? replacing;
  final TileColor? initialColor;
  final CustomButton? existing;

  @override
  ConsumerState<CustomTileDialog> createState() => _CustomTileDialogState();
}

class _CustomTileDialogState extends ConsumerState<CustomTileDialog> {
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.label ?? '');
  final _voiceController = VoiceRecorderController();
  late bool _category = widget.existing?.isCategory ?? false;
  late TileColor? _color = widget.existing?.tileColor ?? widget.initialColor;
  File? _image;
  bool _removeImage = false;
  File? _voiceClip;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    // System photo picker (PHPicker on iOS 14+, Android photo picker): no
    // Photos permission prompt and no usage string (ADR 0016).
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    final path = picked?.path;
    if (path == null) return;
    final file = File(path);
    // Reject an oversized or non-image file immediately, so the parent gets
    // feedback now and a huge photo is never copied into app storage (the store
    // enforces the same caps as a backstop).
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot).toLowerCase();
    final tooBig = await file.length() > CustomButtonStore.maxImageBytes;
    if (!mounted) return;
    if (tooBig || !CustomButtonStore.allowedImageExtensions.contains(ext)) {
      _snack(l10n.imageRejected);
      return;
    }
    setState(() {
      _image = file;
      _removeImage = false;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final label = _label.text.trim();
    if (label.isEmpty || _saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(customButtonsProvider.notifier);
    String? newId;
    try {
      final existing = widget.existing;
      if (existing != null) {
        await notifier.editButton(
          existing.id,
          label: label,
          tileColor: _color,
          imageSource: _image,
          removeImage: _removeImage,
        );
      } else {
        newId = await notifier.addButton(
          boardId: widget.boardId!,
          row: widget.slot!.row,
          col: widget.slot!.col,
          label: label,
          imageSource: _image,
          tileColor: _color,
          replacesId: widget.replacing?.id,
          category: _category,
        );
      }
    } on CustomButtonImageException {
      // Backstop if a too-large/unsupported image slipped past _pickImage.
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(l10n.imageRejected);
      return;
    } catch (_) {
      // Includes a whole-file-corrupt store refusing to overwrite (item 7): the
      // parent's existing buttons are preserved. Never leave the spinner stuck.
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(l10n.customTileSaveFailed);
      return;
    }

    // Attach the optional recorded voice to the brand-new button (ADR 0019).
    // Finalize first so a recording the parent never tapped Stop on is still
    // captured, instead of being silently dropped.
    if (newId != null && !_category) {
      try {
        final clip = await _voiceController.finalize() ?? _voiceClip;
        if (clip != null) {
          await ref.read(customVoiceProvider.notifier).save(newId, clip);
        }
      } catch (_) {
        // The button exists; say so plainly rather than lose the recording
        // without a word (the parent can record it again from the tile).
        if (mounted) _snack(l10n.customTileVoiceFailed);
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final replacing = widget.replacing;
    final existingImage = widget.existing?.imagePath ?? '';
    final showsImage = _image != null || (existingImage.isNotEmpty && !_removeImage);
    final canSave = !_saving && _label.text.trim().isNotEmpty;

    final String title;
    if (_editing) {
      title = _category ? l10n.editCategoryTitle : l10n.editButtonTitle;
    } else if (replacing != null) {
      title = l10n.replaceDialogTitle(replacing.labelFor(lang));
    } else {
      title = l10n.addDialogTitle;
    }

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_editing) ...[
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  key: const ValueKey('custom_tile_kind'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.touch_app_outlined),
                      label: Text(l10n.addKindButton,
                          key: const ValueKey('custom_tile_kind_button')),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.folder_outlined),
                      label: Text(l10n.addKindCategory,
                          key: const ValueKey('custom_tile_kind_category')),
                    ),
                  ],
                  selected: {_category},
                  onSelectionChanged: _saving
                      ? null
                      : (s) => setState(() => _category = s.first),
                ),
              ),
              if (_category) ...[
                const SizedBox(height: 8),
                Text(l10n.addKindCategoryHint, style: LhText.rowSubtitle),
              ],
              const SizedBox(height: 12),
            ],
            if (replacing != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: LhColors.cream2,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Text(
                  l10n.replaceDialogNote(replacing.labelFor(lang)),
                  style: LhText.rowSubtitle,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('custom_tile_label'),
              controller: _label,
              decoration: InputDecoration(
                labelText: _category
                    ? l10n.categoryNameLabel
                    : l10n.customButtonsWordLabel,
              ),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (showsImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.file(
                        _image ?? File(existingImage),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('custom_tile_photo'),
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(showsImage
                      ? l10n.customTileChangePhoto
                      : l10n.customButtonsChoosePhoto),
                ),
                if (showsImage)
                  TextButton(
                    key: const ValueKey('custom_tile_remove_photo'),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _image = null;
                              _removeImage = existingImage.isNotEmpty;
                            }),
                    child: Text(l10n.customTileRemovePhoto),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TileColorPicker(
              value: _color,
              onChanged: (c) {
                if (!_saving) setState(() => _color = c);
              },
            ),
            // Optional: record your own voice for a NEW button at creation time
            // (clinical review). Saved against the new button's id after Save.
            // An existing button records from its own sheet; a category never
            // speaks.
            if (!_editing && !_category) ...[
              const SizedBox(height: 12),
              VoiceRecorderField(
                idHint: widget.boardId ?? 'tile',
                controller: _voiceController,
                onChanged: (f) => _voiceClip = f,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('custom_tile_save'),
          onPressed: canSave ? _save : null,
          child: Text(l10n.customButtonsSave),
        ),
      ],
    );
  }
}
