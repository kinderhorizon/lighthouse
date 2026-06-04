/// Onboarding Screen 3: privacy promise (redesign, the emotional peak).
///
/// Centered Lighthouse mark, a display headline, one warm paragraph, and three
/// check-row reassurances. A small question-mark icon opens the architecture
/// explainer that justifies the claim (its compile-time-gated egress copy is
/// load-bearing privacy content and is preserved).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/services.dart';
import '../../theme/lighthouse_theme.dart';

class PrivacyClaimScreen extends StatelessWidget {
  const PrivacyClaimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Image.asset(
                'assets/brand/lighthouse-mark.png',
                height: 104,
                semanticLabel: 'Lighthouse AAC',
                errorBuilder: (context, error, stack) =>
                    const SizedBox(height: 104),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.onboardingPrivacyHeadline,
                textAlign: TextAlign.center,
                style: LhText.display,
              ),
              const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              l10n.privacyBody,
              textAlign: TextAlign.center,
              style: LhText.lede,
            ),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                _CheckRow(text: l10n.onboardingPrivacyPoint1),
                const SizedBox(height: 12),
                _CheckRow(text: l10n.onboardingPrivacyPoint2),
                const SizedBox(height: 12),
                _CheckRow(text: l10n.onboardingPrivacyPoint3),
              ],
            ),
          ),
            ],
          ),
        ),
        // The "How we know" affordance sits in the top corner, clear of the
        // centered headline, and opens the architecture explainer.
        PositionedDirectional(
          top: 4,
          end: 4,
          child: SafeArea(
            child: IconButton(
              tooltip: l10n.privacyTooltip,
              icon: const Icon(Icons.help_outline, color: LhColors.ink3),
              onPressed: () => _showExplainer(context),
            ),
          ),
        ),
      ],
    );
  }

  void _showExplainer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LhColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.howWeKnowTitle, style: LhText.dialogTitle),
                const SizedBox(height: 12),
                Text(l10n.howWeKnowBody1, style: LhText.body),
                // Gated on the same compile-time config as the features: these
                // describe parent-initiated egress paths that only EXIST once
                // their endpoint is set, so the copy can never claim a data path
                // the build cannot actually take (ADR 0017/0018).
                if (kOtaContentBaseUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l10n.howWeKnowUpdates, style: LhText.body),
                ],
                if (kFeedbackEndpointUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l10n.howWeKnowFeedback, style: LhText.body),
                ],
                const SizedBox(height: 12),
                Text(l10n.howWeKnowBody2, style: LhText.body),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: LhColors.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, color: LhColors.good),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Atkinson Hyperlegible',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LhColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
