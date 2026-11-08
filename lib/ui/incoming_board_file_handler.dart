/// Offers a board file the phone handed to Lighthouse (ADR 0015 amendment), or
/// a whole setup copied from another device (ADR 0023).
///
/// Wraps the board screen, so a file is only offered once onboarding is done
/// and the app is on its main screen (a file opened during onboarding waits).
/// For each file: check it really is a board, ask the parent ("Add this
/// board?"), pass the math gate, then import it as a new, separate board
/// exactly like Settings, Import. The temporary copy is deleted afterwards
/// whatever happens, so a shared vocabulary never lingers on the device
/// (ADR 0015 Decision 4).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../state/state.dart';
import 'settings/device_setup_flow.dart';
import 'settings/math_gate.dart';
import 'settings/shared_boards_screen.dart';

class IncomingBoardFileHandler extends ConsumerStatefulWidget {
  const IncomingBoardFileHandler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<IncomingBoardFileHandler> createState() =>
      _IncomingBoardFileHandlerState();
}

class _IncomingBoardFileHandlerState
    extends ConsumerState<IncomingBoardFileHandler> {
  StreamSubscription<void>? _arrivals;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _arrivals = ref.read(incomingBoardFilesProvider).arrivals.listen((_) {
      unawaited(_offerPending());
    });
    // A file that opened the app (or arrived during onboarding) is waiting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_offerPending());
    });
  }

  @override
  void dispose() {
    _arrivals?.cancel();
    super.dispose();
  }

  /// Offers every waiting file, one at a time. A file that arrives while one
  /// is being offered stays pending on the native side and is picked up by
  /// the next loop turn.
  Future<void> _offerPending() async {
    if (_busy) return;
    _busy = true;
    try {
      while (mounted) {
        final path = await ref.read(incomingBoardFilesProvider).takePending();
        if (path == null) break;
        final file = File(path);
        try {
          if (mounted) await _offer(file);
        } finally {
          _deleteQuietly(file);
        }
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _offer(File file) async {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;

    // A whole setup from another device (ADR 0023) is offered as one.
    final read = await readSetupFile(file);
    if (!mounted) return;
    if (read.tooNew) return _snack(l10n.setupTooNew);
    if (read.setup != null) {
      await offerDeviceSetup(context, ref, read.setup!, gated: false);
      return;
    }

    // Check it is a board before asking anything: a parent who opened some
    // other file with Lighthouse gets a plain answer, not a math gate.
    final AACBoard preview;
    try {
      preview = await const BoardLoader().loadFromFile(file);
    } catch (_) {
      _snack(l10n.incomingBoardNotABoard);
      return;
    }
    if (!mounted) return;

    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(l10n.incomingBoardTitle),
        content: Text(l10n.incomingBoardBody(preview.boardNameFor(lang))),
        actions: [
          TextButton(
            key: const ValueKey('incoming_board_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('incoming_board_add'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.incomingBoardAdd),
          ),
        ],
      ),
    );
    if (add != true || !mounted) return;

    // The same parental gate as Settings, Import (a child must not add boards).
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (gateContext) => Dialog(
        child: MathGate(onUnlocked: () => Navigator.of(gateContext).pop(true)),
      ),
    );
    if (unlocked != true || !mounted) return;

    final registry = await ref.read(boardRegistryProvider.future);
    try {
      final board = await BoardPackImporter(
        registry: registry,
      ).import(file, assignFreshId: true);
      // The registry changed under the providers that list boards; reload them
      // so the new board shows in Home favourites and Custom buttons now.
      ref.invalidate(editableBoardsProvider);
      if (!mounted) return;
      // Put it on the child's board now, or later (Settings, Shared boards).
      await offerToPlaceSharedBoard(
        context,
        id: board.boardId,
        name: board.boardNameFor(lang),
      );
    } on BoardPackImportException {
      _snack(l10n.incomingBoardFailed);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(duration: const Duration(seconds: 3), content: Text(message)),
      );
  }

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      /* best-effort; it is in the OS temp/cache dir */
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
