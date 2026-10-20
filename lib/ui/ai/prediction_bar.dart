/// Dedicated AI Prediction Bar.
///
/// Provides next-word suggestions and AI sentence expansion candidates
/// in a separate strip above the AAC grid.
///
/// INVARIANTS:
/// - Grid buttons never move (motor planning stability).
/// - Suggestions never auto-speak (user autonomy and consent).
/// - Completely offline execution.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_registry.dart';
import '../../l10n/app_localizations.dart';
import '../../logic/ai/ai.dart';
import '../../models/models.dart';
import '../../state/state.dart';
import '../keyboard/smart_keyboard_screen.dart';
import '../theme/lighthouse_theme.dart';
import 'text_assistant_sheet.dart';

class PredictionBar extends ConsumerWidget {
  const PredictionBar({
    required this.board,
    super.key,
  });

  final AACBoard board;

  static const _sentenceBuilder = AISentenceBuilder();
  static const _wordPredictor = AIWordPredictor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(utteranceProvider);
    final locale = Localizations.localeOf(context);
    final langCode = LocaleRegistry.codeForLocale(locale);
    final l10n =
        Localizations.of<AppLocalizations>(context, AppLocalizations);

    // Predict next candidate words based on preceding tokens
    final candidateWords = _wordPredictor.predictNextWords(
      precedingTokens: tokens,
      board: board,
      limit: 4,
    );

    final personalCards = ref.watch(personalCardsProvider).valueOrNull ?? const [];
    final personalButtons = personalCards.map((c) => c.toAacButton()).toList();

    final mergedCandidates = <AACButton>[];
    for (final pb in personalButtons) {
      if (!mergedCandidates.any((c) => c.label == pb.label)) {
        mergedCandidates.add(pb);
      }
      if (mergedCandidates.length >= 2) break;
    }
    for (final cw in candidateWords) {
      if (!mergedCandidates.any((c) => c.label == cw.label)) {
        mergedCandidates.add(cw);
      }
    }

    // If 2 or more words are in the sentence bar, offer an expanded sentence candidate
    String? expandedSentence;
    if (tokens.length >= 2) {
      final expanded = _sentenceBuilder.buildSentence(tokens, langCode);
      if (expanded.isNotEmpty) {
        expandedSentence = expanded;
      }
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: LhColors.cream2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: LhColors.line2),
      ),
      child: Row(
        children: [
          // AI indicator & text typing shortcut
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: LhColors.amber, size: 20),
            tooltip: l10n?.aiCommunicationAssistantTooltip ??
                'AI Communication Assistant',
            onPressed: () => TextAssistantSheet.show(context, ref, board),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_outlined, color: LhColors.brown, size: 20),
            tooltip: 'Smart AAC Keyboard',
            onPressed: () => SmartKeyboardScreen.show(context, ref),
          ),
          const VerticalDivider(width: 8, indent: 8, endIndent: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                if (expandedSentence != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: ActionChip(
                      avatar: const Icon(Icons.auto_fix_high,
                          size: 16, color: LhColors.brown),
                      label: Text(
                        expandedSentence,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: LhColors.brown,
                        ),
                      ),
                      backgroundColor: LhColors.amberTint,
                      side: const BorderSide(color: LhColors.amberLine),
                      onPressed: () {
                        // User explicitly confirmed AI sentence suggestion:
                        // Convert expanded sentence into speech or display
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(expandedSentence!),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                for (final btn in mergedCandidates) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                    child: ActionChip(
                      label: Text(
                        btn.labelFor(langCode),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: LhColors.ink,
                        ),
                      ),
                      backgroundColor: LhColors.surface,
                      side: const BorderSide(color: LhColors.line),
                      onPressed: () {
                        // Safe: commits candidate word to sentence bar upon deliberate tap
                        ref.read(utteranceProvider.notifier).commit(btn);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
