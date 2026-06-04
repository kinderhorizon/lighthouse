/// "Send feedback" screen (ADR 0018), redesign.
///
/// A math-gated parent form: pick a category, type a message, optionally leave
/// an email, and Send. The Settings entry is hidden unless a feedback endpoint
/// is configured (dead-UI gate).
///
/// Privacy (ADR 0018): the payload carries ONLY the typed message, the chosen
/// category, the optional email, and low-entropy triage context (app version,
/// OS version, locale) plus a per-submission random nonce. NEVER the child, the
/// board, usage, or finer device metadata. The relay persists nothing.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../widgets/lh_widgets.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.bug;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _osVersion() =>
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;

    final submission = FeedbackSubmission(
      category: _category,
      message: _messageController.text,
      contactEmail: email.isEmpty ? null : email,
      appVersion: info.version,
      osVersion: _osVersion(),
      locale: Localizations.localeOf(context).toLanguageTag(),
      clientNonce: newClientNonce(),
    );

    final reason = submission.validationError();
    if (reason != null) {
      setState(() => _error = _validationMessage(l10n, reason));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref.read(feedbackClientProvider).send(submission);
    if (!mounted) return;

    switch (result) {
      case FeedbackSendResult.sent:
        setState(() {
          _busy = false;
          _sent = true;
        });
      case FeedbackSendResult.invalid:
        setState(() {
          _busy = false;
          _error = l10n.feedbackErrorEmpty;
        });
      case FeedbackSendResult.notConfigured:
      case FeedbackSendResult.rejected:
      case FeedbackSendResult.networkError:
        setState(() {
          _busy = false;
          _error = l10n.feedbackErrorNetwork;
        });
    }
  }

  String _validationMessage(AppLocalizations l10n, String reason) {
    switch (reason) {
      case 'badEmail':
        return l10n.feedbackErrorEmail;
      case 'tooLong':
        return l10n.feedbackErrorTooLong;
      case 'empty':
      default:
        return l10n.feedbackErrorEmpty;
    }
  }

  void _reset() {
    setState(() {
      _sent = false;
      _error = null;
      _messageController.clear();
      _emailController.clear();
      _category = FeedbackCategory.bug;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: lhAppBar(context, title: l10n.feedbackTitle),
      body: SafeArea(
        child: _sent ? _thanks(l10n) : _form(l10n),
      ),
    );
  }

  Widget _thanks(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: LhColors.goodBg,
              ),
              child: const Icon(Icons.check_rounded, size: 48, color: LhColors.good),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.feedbackThanksTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Atkinson Hyperlegible',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: LhColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                l10n.feedbackThanksBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Atkinson Hyperlegible',
                  fontSize: 18,
                  height: 1.5,
                  color: LhColors.ink2,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: _reset,
                  child: Text(l10n.feedbackSendAnother),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: Text(l10n.feedbackBackToBoard),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.feedbackBody,
              style: LhText.body.copyWith(color: LhColors.ink2)),
          const SizedBox(height: 22),
          _FieldLabel(l10n.feedbackCategoryLabel),
          const SizedBox(height: 8),
          SegmentedButton<FeedbackCategory>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: FeedbackCategory.bug,
                label: Text(l10n.feedbackCategoryBug),
                icon: const Icon(Icons.bug_report_outlined),
              ),
              ButtonSegment(
                value: FeedbackCategory.suggestion,
                label: Text(l10n.feedbackCategorySuggestion),
                icon: const Icon(Icons.lightbulb_outline),
              ),
              ButtonSegment(
                value: FeedbackCategory.other,
                label: Text(l10n.feedbackCategoryOther),
                icon: const Icon(Icons.chat_bubble_outline),
              ),
            ],
            selected: {_category},
            onSelectionChanged:
                _busy ? null : (s) => setState(() => _category = s.first),
          ),
          const SizedBox(height: 22),
          _FieldLabel(l10n.feedbackMessageLabel),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('feedback_message'),
            controller: _messageController,
            enabled: !_busy,
            maxLines: 6,
            maxLength: kFeedbackMessageMaxLength,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(hintText: l10n.feedbackMessageHint),
          ),
          const SizedBox(height: 12),
          _FieldLabel(l10n.feedbackEmailLabel),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('feedback_email'),
            controller: _emailController,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(hintText: l10n.feedbackEmailHint),
          ),
          const SizedBox(height: 14),
          Text(l10n.feedbackPrivacyNote,
              style: const TextStyle(
                fontFamily: 'Atkinson Hyperlegible',
                fontSize: 14,
                height: 1.45,
                color: LhColors.ink3,
              )),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'Atkinson Hyperlegible',
                    fontSize: 16,
                    color: Color(0xFFB3261E))),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('feedback_send'),
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: Text(_busy ? l10n.feedbackSending : l10n.feedbackSend),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Atkinson Hyperlegible',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: LhColors.amberDeep,
      ),
    );
  }
}
