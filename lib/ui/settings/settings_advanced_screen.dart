/// Advanced Settings tier (math-gated entry), redesign.
///
/// Clinical / power-user controls grouped with parent-readable names (handoff):
/// VOICE, HOW THE BOARD LOOKS, MOVING AROUND, LEARNING.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../tour/first_use_tip.dart';
import '../widgets/lh_widgets.dart';

class SettingsAdvancedScreen extends ConsumerWidget {
  const SettingsAdvancedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(settingsNotifierProvider).valueOrNull ?? SettingsState.defaults;

    return FirstUseTipHost(
      tipKey: FirstUseTipsStore.advancedKey,
      title: l10n.tipAdvancedTitle,
      body: l10n.tipAdvancedBody,
      builder: (context, anchorKey) => Scaffold(
      appBar: lhAppBar(context, title: l10n.advancedTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            LhSectionLabel(l10n.sectionVoice, key: anchorKey),
            LhSettingsRow(
              icon: Icons.record_voice_over_outlined,
              title: l10n.voiceOutput,
              subtitle: _ttsLabel(l10n, settings.ttsMode),
              onTap: () => _pickTts(context, ref, settings.ttsMode),
            ),

            LhSectionLabel(l10n.sectionVisual),
            LhSettingsRow(
              icon: Icons.auto_awesome_rounded,
              title: l10n.glowStyle,
              subtitle: _glowLabel(l10n, settings.glowStyle),
              onTap: () => _pickGlow(context, ref, settings.glowStyle),
            ),
            LhSettingsRow(
              icon: Icons.pan_tool_outlined,
              title: l10n.hitboxExpansion,
              subtitle: _hitboxLabel(l10n, settings.hitboxMagnitude),
              onTap: () => _pickHitbox(context, ref, settings.hitboxMagnitude),
            ),
            LhSwitchRow(
              icon: Icons.title_rounded,
              title: l10n.showWordOnTile,
              subtitle: l10n.showWordOnTileSubtitle,
              // The stored setting is hideTileText; the toggle is phrased as
              // SHOW, so value and write are inverted here. Text and pictogram
              // can never both be off: turning the word off forces the
              // pictogram on (handled in the notifier), and this row reflects
              // that on the next rebuild.
              value: !settings.hideTileText,
              onChanged: (show) => ref
                  .read(settingsNotifierProvider.notifier)
                  .setHideTileText(!show),
            ),
            LhSwitchRow(
              icon: Icons.image_outlined,
              title: l10n.showPictogramOnTile,
              subtitle: l10n.showPictogramOnTileSubtitle,
              // Complement of the row above (stored as hidePictogram, inverted
              // to SHOW). Turning the pictogram off forces the word on; both
              // can never be off at once.
              value: !settings.hidePictogram,
              onChanged: (show) => ref
                  .read(settingsNotifierProvider.notifier)
                  .setHidePictogram(!show),
            ),

            LhSectionLabel(l10n.sectionNavigation),
            LhSwitchRow(
              icon: Icons.home_outlined,
              title: l10n.autoReturnToHome,
              subtitle: l10n.autoReturnToHomeSubtitle,
              value: settings.autoReturnToHome,
              onChanged: (v) => ref
                  .read(settingsNotifierProvider.notifier)
                  .setAutoReturnToHome(v),
            ),

            LhSectionLabel(l10n.sectionLearning),
            LhSettingsRow(
              icon: Icons.delete_outline_rounded,
              title: l10n.resetLearnedState,
              subtitle: l10n.resetLearnedStateSubtitle,
              trailing: LhRowTrailing.none,
              onTap: () => _confirmAndReset(context, ref),
            ),
          ],
        ),
      ),
      ),
    );
  }

  static String _ttsLabel(AppLocalizations l10n, TtsMode m) => switch (m) {
        TtsMode.on => l10n.ttsModeOn,
        TtsMode.onRequest => l10n.ttsModeOnRequest,
        TtsMode.off => l10n.ttsModeOff,
        TtsMode.als => l10n.ttsModeAls,
      };

  static String _glowLabel(AppLocalizations l10n, GlowStyle s) => switch (s) {
        GlowStyle.halo => l10n.glowStyleHalo,
        GlowStyle.ring => l10n.glowStyleRing,
        GlowStyle.lift => l10n.glowStyleLift,
        GlowStyle.dot => l10n.glowStyleDot,
        GlowStyle.off => l10n.glowStyleOff,
      };

  static String _hitboxLabel(AppLocalizations l10n, HitboxMagnitude h) =>
      switch (h) {
        HitboxMagnitude.none => l10n.hitboxNone,
        HitboxMagnitude.subtle => l10n.hitboxSubtle,
        HitboxMagnitude.maximum => l10n.hitboxMaximum,
      };

  Future<void> _pickTts(
      BuildContext context, WidgetRef ref, TtsMode current) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _chooser<TtsMode>(
      context,
      title: l10n.voiceOutput,
      values: TtsMode.values,
      current: current,
      label: (m) => _ttsLabel(l10n, m),
    );
    if (chosen == null) return;
    await ref.read(settingsNotifierProvider.notifier).setTtsMode(chosen);
  }

  Future<void> _pickGlow(
      BuildContext context, WidgetRef ref, GlowStyle current) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _chooser<GlowStyle>(
      context,
      title: l10n.glowStyle,
      values: GlowStyle.values,
      current: current,
      label: (s) => _glowLabel(l10n, s),
    );
    if (chosen == null) return;
    await ref.read(settingsNotifierProvider.notifier).setGlowStyle(chosen);
  }

  Future<void> _pickHitbox(
      BuildContext context, WidgetRef ref, HitboxMagnitude current) async {
    final l10n = AppLocalizations.of(context);
    final chosen = await _chooser<HitboxMagnitude>(
      context,
      title: l10n.hitboxExpansion,
      values: HitboxMagnitude.values,
      current: current,
      label: (h) => _hitboxLabel(l10n, h),
    );
    if (chosen == null) return;
    await ref.read(settingsNotifierProvider.notifier).setHitboxMagnitude(chosen);
  }

  Future<T?> _chooser<T>(
    BuildContext context, {
    required String title,
    required List<T> values,
    required T current,
    required String Function(T) label,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final v in values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(label(v),
                          style: v == current
                              ? LhText.rowTitle
                              : LhText.rowTitle
                                  .copyWith(fontWeight: FontWeight.w400)),
                    ),
                    if (v == current)
                      const Icon(Icons.check_rounded, color: LhColors.brown),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmAndReset(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.resetLearnedStateConfirmTitle),
          content: Text(l10n.resetLearnedStateConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.erase),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    var ok = true;
    try {
      // Wipe the persisted bandit + event log, then the volatile in-memory
      // context. Order matters only for crash-window safety.
      await ref.read(banditRepositoryProvider).clearAll();
      ref.read(contextManagerProvider).reset();
      ref.read(contextEpochProvider.notifier).bump();
      ref.invalidate(currentPredictionsProvider);
      ref.invalidate(currentGlowProvider);
    } catch (_) {
      ok = false;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
            ok ? l10n.learnedStateCleared : l10n.couldNotClearLearnedState),
      ),
    );
  }
}
