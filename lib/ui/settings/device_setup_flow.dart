/// Copying a child's whole setup to another device (ADR 0023): the parent's
/// side of it. Sending writes one file and opens the share sheet; receiving
/// asks before replacing anything, behind the parental gate.
///
/// Parent feedback: sharing a board only sends the page on screen (its folders
/// cannot travel in a single-board file), so a parent who wanted to move a
/// child's words to a new tablet found only the basic board there.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import 'math_gate.dart';

/// Writes this device's setup to a file and opens the share sheet, after
/// saying what goes and what stays behind. The caller has already passed the
/// parental gate. The file is deleted afterwards whatever happens.
Future<void> sendDeviceSetup(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  // iPad needs a popover anchor for the share sheet or it throws.
  final box = context.findRenderObject() as RenderBox?;
  final origin = (box != null && box.hasSize)
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final registry = await ref.read(boardRegistryProvider.future);
  SetupExport export;
  try {
    export = await ref
        .read(deviceSetupServiceProvider)
        .prepare(registry, fileBaseName: l10n.setupFileName);
  } catch (_) {
    if (context.mounted) _toast(context, l10n.setupSendFailed);
    return;
  }
  try {
    if (!context.mounted) return;
    final leftBehind = export.photosLeftBehind + export.recordingsLeftBehind;
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.setupSendTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.setupSendBody),
            if (leftBehind > 0) ...[
              const SizedBox(height: 12),
              Text(l10n.setupSendLeftBehind),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('setup_send_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('setup_send_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.setupSendConfirm),
          ),
        ],
      ),
    );
    if (send != true || !context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(export.file.path)],
        // Travels with the file, so whoever opens it knows what to do.
        text: l10n.setupShareMessage,
        subject: l10n.setupFileName,
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    if (context.mounted) _toast(context, l10n.setupSendFailed);
  } finally {
    try {
      if (export.file.existsSync()) await export.file.delete();
    } catch (_) {
      /* best-effort; it is in the temp directory */
    }
  }
}

/// Reads [file] as a setup. Returns the setup; null when the file is not a
/// setup (the caller may treat it as a single board). Says so and returns
/// null when the setup is from a newer Lighthouse; [tooNew] is then set.
Future<({DeviceSetup? setup, bool tooNew})> readSetupFile(File file) async {
  try {
    return (setup: await DeviceSetup.readFile(file), tooNew: false);
  } on DeviceSetupTooNewException {
    return (setup: null, tooNew: true);
  } on DeviceSetupException {
    return (setup: null, tooNew: false);
  }
}

/// Asks before replacing this device's setup with [setup], passes the parental
/// gate unless [gated] (Settings has asked already), then replaces it and says
/// so. Returns true when the setup was copied.
Future<bool> offerDeviceSetup(
  BuildContext context,
  WidgetRef ref,
  DeviceSetup setup, {
  required bool gated,
}) async {
  final l10n = AppLocalizations.of(context);
  final replace = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(l10n.setupReplaceTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.setupReplaceBody),
          const SizedBox(height: 12),
          Text(l10n.setupReplaceNoPhotos),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('setup_replace_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('setup_replace_confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.setupReplaceConfirm),
        ),
      ],
    ),
  );
  if (replace != true || !context.mounted) return false;
  if (!gated) {
    // The same parental gate as Settings: a child must not replace the board.
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (gateContext) => Dialog(
        child: MathGate(onUnlocked: () => Navigator.of(gateContext).pop(true)),
      ),
    );
    if (unlocked != true || !context.mounted) return false;
  }
  final messenger = ScaffoldMessenger.of(context);
  try {
    await applyDeviceSetup(ref, setup);
  } catch (_) {
    _show(messenger, l10n.setupFailed);
    return false;
  }
  // The language may have just changed with the setup: say it in the new one.
  final now = context.mounted ? AppLocalizations.of(context) : l10n;
  _show(messenger, now.setupReplaced);
  return true;
}

void _toast(BuildContext context, String message) =>
    _show(ScaffoldMessenger.of(context), message);

void _show(ScaffoldMessengerState messenger, String message) {
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(duration: const Duration(seconds: 4), content: Text(message)),
    );
}
