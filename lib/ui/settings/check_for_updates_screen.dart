/// "Check for updates" screen (ADR 0017), redesign.
///
/// The single, voluntary, parent-initiated OTA surface: the app only contacts
/// the content server when the parent taps "Check now". Math-gated, and the
/// Settings entry is hidden unless a content endpoint is configured. A found
/// correction is shown and only applied on a second confirm; it takes effect at
/// next launch (never mid-session for the child).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../widgets/lh_widgets.dart';
import '../widgets/restart_widget.dart';

class CheckForUpdatesScreen extends ConsumerStatefulWidget {
  const CheckForUpdatesScreen({super.key});

  @override
  ConsumerState<CheckForUpdatesScreen> createState() =>
      _CheckForUpdatesScreenState();
}

class _CheckForUpdatesScreenState extends ConsumerState<CheckForUpdatesScreen> {
  bool _busy = false;
  UpdateCheck? _result;
  bool _applied = false;

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _applied = false;
      _result = null;
    });
    final service = await ref.read(contentUpdateServiceProvider.future);
    final result = await service.check();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  Future<void> _apply(ContentManifest manifest) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      final service = await ref.read(contentUpdateServiceProvider.future);
      await service.apply(manifest);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _applied = true;
        _result = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.otaError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showIdle = !_applied && _result == null && !_busy;
    return Scaffold(
      appBar: lhAppBar(context, title: l10n.otaTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.otaBody, style: LhText.body.copyWith(color: LhColors.ink2)),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('ota_check_now'),
                onPressed: _busy ? null : _check,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_busy ? l10n.otaChecking : l10n.otaCheckNow),
              ),
              const SizedBox(height: 26),
              if (_applied) ...[
                // The applied overlay is on disk but the running app cached the
                // old content at startup; a root re-mount re-reads it. Apply
                // only ever happens here in Settings (parent-driven), so doing
                // it now never disturbs a child mid-session. No OS restart (iOS
                // forbids self-relaunch); see RestartWidget.
                _SuccessCard(title: l10n.otaApplied, subtitle: l10n.otaApplyFallback),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey('ota_show_now'),
                  onPressed: () => RestartWidget.restart(context),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.otaShowNow),
                ),
              ] else if (_result != null)
                _resultView(l10n, _result!)
              else if (showIdle)
                Text(l10n.otaLastCheckedNever,
                    style: const TextStyle(
                        fontFamily: 'Atkinson Hyperlegible',
                        fontSize: 16,
                        color: LhColors.ink3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultView(AppLocalizations l10n, UpdateCheck result) {
    switch (result.status) {
      case UpdateStatus.available:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(icon: Icons.download_rounded, text: l10n.otaAvailable),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('ota_apply'),
              onPressed: _busy ? null : () => _apply(result.manifest!),
              child: Text(_busy ? l10n.otaApplying : l10n.otaApply),
            ),
          ],
        );
      case UpdateStatus.upToDate:
        return _SuccessCard(title: l10n.otaUpToDate, subtitle: l10n.otaCheckedJustNow);
      case UpdateStatus.incompatible:
        return _InfoRow(icon: Icons.system_update, text: l10n.otaIncompatible);
      case UpdateStatus.notConfigured:
      case UpdateStatus.error:
        return _InfoRow(icon: Icons.info_outline, text: l10n.otaError);
    }
  }
}

/// Calm success card (good-bg) with a green check medallion.
class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: LhColors.goodBg,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: LhColors.good,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: 'Atkinson Hyperlegible',
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: LhColors.ink,
                    )),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(
                          fontFamily: 'Atkinson Hyperlegible',
                          fontSize: 16,
                          color: LhColors.ink2)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: LhColors.ink2),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: LhText.body)),
      ],
    );
  }
}
