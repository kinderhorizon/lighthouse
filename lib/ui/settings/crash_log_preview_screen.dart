/// Crash logs: review then send (ADR 0002), redesign.
///
/// The "verify before you send" surface. When there are no logs it shows a
/// reassurance empty state ("Nothing has gone wrong"). When logs exist it lists
/// each one's parsed JSON inline so the parent can read EXACTLY what would
/// leave the device, then a "Send crash logs" action.
///
/// Egress is ALWAYS parent-initiated and NEVER app-originated: Send opens the
/// device's own mail composer, pre-addressed to KHF with the log file(s)
/// attached, and the PARENT taps send. No KHF server is contacted and no HTTP
/// client is used. If no mail account is configured (common on iOS), it falls
/// back to the OS share sheet, still parent-initiated and still server-less.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../widgets/lh_widgets.dart';
import 'math_gate.dart';

class CrashLogPreviewScreen extends ConsumerStatefulWidget {
  const CrashLogPreviewScreen({super.key});

  @override
  ConsumerState<CrashLogPreviewScreen> createState() =>
      _CrashLogPreviewScreenState();
}

class _CrashLogPreviewScreenState
    extends ConsumerState<CrashLogPreviewScreen> {
  late Future<List<CrashLog>> _logs;

  /// Pre-addressed crash-log destination. Egress is always parent-initiated.
  static const _crashLogRecipient = 'bugs@kinderhorizon.org';

  @override
  void initState() {
    super.initState();
    _logs = ref.read(crashLogStoreProvider).readAll();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: lhAppBar(context, title: l10n.crashLogsTitle),
      body: SafeArea(
        child: FutureBuilder<List<CrashLog>>(
          future: _logs,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final logs = snap.data ?? const <CrashLog>[];
            if (logs.isEmpty) {
              return LhEmptyState(
                icon: Icons.check_rounded,
                iconColor: LhColors.good,
                headline: l10n.crashEmptyHeadline,
                body: l10n.crashEmptyBody,
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(28),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) {
                      final pretty = const JsonEncoder.withIndent('  ')
                          .convert(logs[i].toJson());
                      return Container(
                        decoration: BoxDecoration(
                          color: LhColors.surface,
                          borderRadius: const BorderRadius.all(Radius.circular(18)),
                          border: Border.all(color: LhColors.line),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          pretty,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.4,
                            color: LhColors.ink2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _SendBar(
                  onSend: () => _sendCrashLogs(context),
                  onBack: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// See the class doc: parent-initiated, server-less, never automatic. Gated
  /// behind the parental math gate so a child cannot trigger an egress, even
  /// though viewing the logs (the verify step) is left ungated.
  Future<void> _sendCrashLogs(BuildContext context) async {
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        child: MathGate(onUnlocked: () => Navigator.of(ctx).pop(true)),
      ),
    );
    if (!context.mounted || unlocked != true) return;

    final l10n = AppLocalizations.of(context);
    final store = ref.read(crashLogStoreProvider);
    final files = await store.list();
    if (!context.mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(l10n.noCrashLogsToShare),
        ),
      );
      return;
    }
    try {
      // Opens the composer; the user must tap send. A cancel resolves normally
      // (no throw), so cancelling does NOT trigger the share-sheet fallback.
      await FlutterEmailSender.send(
        Email(
          recipients: const [_crashLogRecipient],
          subject: l10n.shareSubject,
          body: l10n.crashEmailBody,
          attachmentPaths: files.map((f) => f.path).toList(),
          isHTML: false,
        ),
      );
    } catch (_) {
      // No mail account / composer unavailable: fall back to the OS share sheet
      // so the parent can still choose how to send. Still no server.
      if (!context.mounted) return;
      await _shareCrashLogsViaSheet(context, files, l10n);
    }

    // Once the logs have been handed off, clear them so the NEXT crash sends
    // only the new report (no growing pile of already-sent logs). iOS does not
    // reliably report sent-vs-cancelled, so we clear after the hand-off either
    // way; a fresh crash regenerates a log if the parent needs to resend.
    await store.clear();
    if (!mounted) return;
    setState(() {
      _logs = ref.read(crashLogStoreProvider).readAll();
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(l10n.crashLogsSentCleared),
      ),
    );
  }

  Future<void> _shareCrashLogsViaSheet(
    BuildContext context,
    List<File> files,
    AppLocalizations l10n,
  ) async {
    // iPad/macOS require a popover anchor rect or share_plus throws. Anchor to
    // this screen's render box; ignored on iPhone/Android.
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final params = ShareParams(
      files: files.map((f) => XFile(f.path)).toList(),
      subject: l10n.shareSubject,
      text: l10n.shareBody,
      sharePositionOrigin: origin,
    );
    await SharePlus.instance.share(params);
  }
}

/// Footer with the send action plus a way back to the board, on a
/// hairline-topped surface bar. Two buttons so that after sending (which hands
/// off to the mail app and returns here) the parent has a clear exit rather
/// than only the prominent Send button.
class _SendBar extends StatelessWidget {
  const _SendBar({required this.onSend, required this.onBack});

  final VoidCallback onSend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: LhColors.cream,
        border: Border(top: BorderSide(color: LhColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed: onBack,
              child: Text(l10n.feedbackBackToBoard),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.email_outlined),
              label: Text(l10n.shareCrashLogs),
            ),
          ),
        ],
      ),
    );
  }
}
