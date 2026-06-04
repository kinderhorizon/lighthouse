/// Onboarding Screen 2: where will your child use Lighthouse? (redesign).
///
/// A context-label question presented as four large 2x2 choice cards. Used to
/// label the first WiFi SSID hash seen at home for parent-facing UI. The
/// bandit's behavior is identical with or without this answer; it is not a
/// prior-seeding question, and it can be skipped. See ADR 0003 § Onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/services.dart';
import '../../../state/state.dart';
import '../../theme/lighthouse_theme.dart';

class HomeLabelScreen extends ConsumerWidget {
  const HomeLabelScreen({super.key});

  static String labelFor(AppLocalizations l10n, OnboardingHomeLabel value) {
    return switch (value) {
      OnboardingHomeLabel.home => l10n.placeHome,
      OnboardingHomeLabel.school => l10n.placeSchool,
      OnboardingHomeLabel.both => l10n.placeBoth,
      OnboardingHomeLabel.other => l10n.placeOther,
    };
  }

  static String _subFor(AppLocalizations l10n, OnboardingHomeLabel value) {
    return switch (value) {
      OnboardingHomeLabel.home => l10n.placeHomeSub,
      OnboardingHomeLabel.school => l10n.placeSchoolSub,
      OnboardingHomeLabel.both => l10n.placeBothSub,
      OnboardingHomeLabel.other => l10n.placeOtherSub,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(onboardingNotifierProvider).valueOrNull?.homeLabel;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 18, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingPlaceTitle, style: LhText.display),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(l10n.onboardingPlaceBody, style: LhText.lede),
          ),
          const SizedBox(height: 28),
          // A 2x2 grid of choice cards. Built as IntrinsicHeight rows (not a
          // fixed-aspect GridView) so each card sizes to its own text and never
          // clips at large text scales.
          for (var i = 0; i < OnboardingHomeLabel.values.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  for (var j = i;
                      j < i + 2 && j < OnboardingHomeLabel.values.length;
                      j++) ...[
                    if (j > i) const SizedBox(width: 16),
                    Expanded(
                      child: _ChoiceCard(
                        title: labelFor(l10n, OnboardingHomeLabel.values[j]),
                        subtitle: _subFor(l10n, OnboardingHomeLabel.values[j]),
                        selected: OnboardingHomeLabel.values[j] == selected,
                        onTap: () => ref
                            .read(onboardingNotifierProvider.notifier)
                            .setHomeLabel(OnboardingHomeLabel.values[j]),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? LhColors.amberTint : LhColors.surface,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: LhMotion.fast,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(
              color: selected ? LhColors.amber : LhColors.line2,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Atkinson Hyperlegible',
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: LhColors.ink,
                  )),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LhText.rowSubtitle),
            ],
          ),
        ),
      ),
    );
  }
}
