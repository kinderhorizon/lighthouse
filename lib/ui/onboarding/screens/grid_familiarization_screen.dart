/// Onboarding Screen 1: meet the board (redesign).
///
/// Renders the Home Core board with a "tap a tile to hear it" headline. No data
/// seeding: the parent's exploration here does NOT update the bandit. Pure grid
/// literacy, plus the "buttons never move, the glow points" promise. See ADR
/// 0003 § Onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/models.dart';
import '../../../state/state.dart';
import '../../theme/lighthouse_theme.dart';
import '../../ui.dart';

class GridFamiliarizationScreen extends ConsumerWidget {
  const GridFamiliarizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final boardAsync = ref.watch(defaultBoardProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 18, 40, 10),
          child: Text(l10n.onboardingGridTitle, style: LhText.display),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 0, 40, 14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(l10n.onboardingGridBody, style: LhText.lede),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Container(
              decoration: BoxDecoration(
                color: LhColors.surface,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
                border: Border.all(color: LhColors.line),
                boxShadow: LhShadows.card,
              ),
              clipBehavior: Clip.antiAlias,
              padding: const EdgeInsets.all(6),
              child: boardAsync.when(
                data: (board) => _SpeakOnlyGrid(board: board),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeakOnlyGrid extends ConsumerWidget {
  const _SpeakOnlyGrid({required this.board});

  final AACBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AACGrid(
      board: board,
      onButtonTap: (button) async {
        // Folder buttons are spoken by their label rather than navigated away
        // from; the parent should never be sent deeper mid-familiarization.
        final tts = ref.read(ttsEngineProvider);
        final locale = Localizations.localeOf(context);
        final text = button.voiceOutFor(locale.languageCode) ?? button.label;
        if (text.isEmpty) return;
        await tts.speak(text, locale: locale);
      },
    );
  }
}
