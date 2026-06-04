/// Primary Settings tier (no gate), redesign information architecture.
///
/// Frequency-first, four section headers (handoff): Language at the very top
/// (no header), then "Your child's board", "How the app behaves", and
/// "Updates & support" with the rare technical task (Crash logs) LAST, then
/// "About". The calm surface lets a parent under stress find what they need in
/// two taps.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../i18n/locale_registry.dart';
import '../../l10n/app_localizations.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../tour/tour_controller.dart';
import '../widgets/lh_widgets.dart';
import 'about_screen.dart';
import 'check_for_updates_screen.dart';
import 'crash_log_preview_screen.dart';
import 'custom_buttons_screen.dart';
import 'feedback_screen.dart';
import 'home_favourites_screen.dart';
import 'math_gate.dart';
import 'settings_advanced_screen.dart';

class SettingsPrimaryScreen extends ConsumerWidget {
  const SettingsPrimaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final privacyPolicyUrl = ref.watch(privacyPolicyUrlProvider);

    return Scaffold(
      appBar: lhAppBar(context, title: l10n.settingsTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 40),
          children: [
            // Language sits at the very top, with no section header.
            LhSettingsRow(
              icon: Icons.language,
              title: l10n.language,
              subtitle: _localeLabel(context, settings?.localeOverride),
              onTap: () => _pickLocale(context, ref),
            ),

            LhSectionLabel(l10n.sectionYourChildsBoard),
            LhSettingsRow(
              icon: Icons.star_outline_rounded,
              title: l10n.homeFavouritesTitle,
              subtitle: l10n.homeFavouritesSubtitle,
              onTap: () => _openGated(context, const HomeFavouritesScreen()),
            ),
            LhSettingsRow(
              icon: Icons.add_photo_alternate_outlined,
              title: l10n.customButtonsTitle,
              subtitle: l10n.customButtonsSubtitle,
              onTap: () => _openGated(context, const CustomButtonsScreen()),
            ),
            LhSettingsRow(
              icon: Icons.ios_share_rounded,
              title: l10n.exportBoardPack,
              subtitle: l10n.exportBoardPackSubtitle,
              trailing: LhRowTrailing.none,
              onTap: () => _exportBoardPack(context, ref),
            ),
            LhSettingsRow(
              icon: Icons.download_rounded,
              title: l10n.importBoardPack,
              subtitle: l10n.importBoardPackSubtitle,
              trailing: LhRowTrailing.none,
              onTap: () => _importBoardPack(context, ref),
            ),

            LhSectionLabel(l10n.sectionHowAppBehaves),
            LhSettingsRow(
              icon: Icons.tune_rounded,
              title: l10n.advancedSettings,
              subtitle: l10n.advancedSettingsSubtitle,
              onTap: () => _openGated(context, const SettingsAdvancedScreen()),
            ),

            LhSectionLabel(l10n.sectionUpdatesSupport),
            // Re-run the guided tour any time (ADR 0020). Pops back to the board
            // (where the tour overlay lives) and starts it.
            LhSettingsRow(
              icon: Icons.lightbulb_outline_rounded,
              title: l10n.tourSettingsRowTitle,
              subtitle: l10n.tourSettingsRowSubtitle,
              onTap: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                ref.read(tourControllerProvider.notifier).start();
              },
            ),
            // OTA + feedback keep their dead-UI gates: the row only appears once
            // an endpoint is configured, so a parent never taps a dead button.
            if (kOtaContentBaseUrl.isNotEmpty)
              LhSettingsRow(
                icon: Icons.refresh_rounded,
                title: l10n.otaTitle,
                subtitle: l10n.otaSettingsSubtitle,
                onTap: () => _openGated(context, const CheckForUpdatesScreen()),
              ),
            if (kFeedbackEndpointUrl.isNotEmpty)
              LhSettingsRow(
                icon: Icons.chat_bubble_outline_rounded,
                title: l10n.feedbackTitle,
                subtitle: l10n.feedbackSettingsSubtitle,
                onTap: () => _openGated(context, const FeedbackScreen()),
              ),
            LhSettingsRow(
              icon: Icons.auto_awesome_rounded,
              title: l10n.rerunOnboarding,
              subtitle: l10n.rerunOnboardingSubtitle,
              onTap: () => _rerunOnboarding(context, ref),
            ),
            // Crash logs LAST, where a rare technical task belongs. Viewing is
            // ungated (read-only); the Send action lives inside the screen.
            LhSettingsRow(
              icon: Icons.shield_outlined,
              title: l10n.crashLogsTitle,
              subtitle: l10n.crashLogsRowSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CrashLogPreviewScreen(),
                ),
              ),
            ),

            LhSectionLabel(l10n.sectionAbout),
            LhSettingsRow(
              icon: Icons.favorite_outline_rounded,
              title: l10n.aboutLighthouse,
              subtitle: l10n.aboutLighthouseSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
            // Hosted privacy policy. Dead-UI gate: appears only once a policy
            // URL is baked in. Not math-gated: public read-only information.
            if (privacyPolicyUrl.isNotEmpty)
              LhSettingsRow(
                icon: Icons.shield_moon_outlined,
                title: l10n.privacyPolicy,
                subtitle: l10n.privacyPolicySubtitle,
                trailing: LhRowTrailing.external,
                onTap: () => _openPrivacyPolicy(context, privacyPolicyUrl),
              ),
          ],
        ),
      ),
    );
  }

  /// The current-locale subtitle. Endonyms come from the registry; the
  /// "follow system" label is the only localized string here.
  String _localeLabel(BuildContext context, String? code) {
    if (code == null) return AppLocalizations.of(context).followSystem;
    return LocaleRegistry.specForCode(code)?.nativeName ??
        AppLocalizations.of(context).followSystem;
  }

  // Sentinel popped by the "Follow system" option. showDialog returns null on
  // dismiss, so we must NOT use null to mean "Follow system": every option pops
  // a non-null value; null reaches us only on dismiss (treated as no change).
  static const _followSystem = '__follow_system__';

  Future<void> _pickLocale(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final currentOverride =
        ref.read(settingsNotifierProvider).valueOrNull?.localeOverride;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text(l10n.language),
          children: [
            _localeOption(context, currentOverride, null, l10n.followSystem),
            for (final spec in LocaleRegistry.all)
              _localeOption(
                  context, currentOverride, spec.code, spec.nativeName),
          ],
        );
      },
    );
    if (chosen == null || !context.mounted) return;
    final newOverride = chosen == _followSystem ? null : chosen;
    await ref
        .read(settingsNotifierProvider.notifier)
        .setLocaleOverride(newOverride);
  }

  Widget _localeOption(BuildContext context, String? currentOverride,
      String? code, String label) {
    final isCurrent = code == currentOverride;
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(code ?? _followSystem),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: isCurrent
                      ? LhText.rowTitle
                      : LhText.rowTitle.copyWith(fontWeight: FontWeight.w400)),
            ),
            if (isCurrent)
              const Icon(Icons.check_rounded, color: LhColors.brown),
          ],
        ),
      ),
    );
  }

  Future<void> _rerunOnboarding(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.rerunOnboardingConfirmTitle),
          content: Text(l10n.rerunOnboardingConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.rerun),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref.read(onboardingNotifierProvider.notifier).reset();
    // Re-arm the first-use tips too, so the whole first-run experience
    // (onboarding + tour offer + every contextual tip) replays (ADR 0020).
    await ref.read(firstUseTipsStoreProvider).reset();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _importBoardPack(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    if (!await _passesGate(context) || !context.mounted) return;
    // Document picker (UIDocumentPickerViewController on iOS): does NOT pull
    // DKImagePickerController, so it adds no Photos/Camera/location frameworks
    // (ADR 0016). iOS / macOS match on a Uniform Type Identifier (NOT the bare
    // extension, which is why the picker silently never opened on iPad), Android
    // on the MIME type; the desktop falls back to the extension. We still
    // re-check the extension below as a backstop. ".json" maps to public.json.
    const jsonGroup = XTypeGroup(
      label: 'Board pack',
      extensions: ['json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );
    final picked = await openFile(acceptedTypeGroups: [jsonGroup]);
    if (!context.mounted) return;
    if (picked == null) return;

    final pickedPath = picked.path;
    if (pickedPath.isEmpty || !pickedPath.toLowerCase().endsWith('.json')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(l10n.couldNotReadFile),
        ),
      );
      return;
    }

    final registry = await ref.read(boardRegistryProvider.future);
    final importer = BoardPackImporter(registry: registry);
    try {
      // ADR 0015: a received pack imports as a fresh, separate board (re-ided +
      // namespaced) so it never overwrites the recipient's own boards. It
      // starts cold: shared vocabulary transfers structure, not learning.
      final board = await importer.import(File(pickedPath), assignFreshId: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(l10n.importedBoard(board.boardName)),
        ),
      );
    } on BoardPackImportException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(l10n.couldNotImport(e.message)),
        ),
      );
    }
  }

  /// Shows the parental math gate and resolves true when it is solved. The one
  /// gate used across the board / maintenance actions so a child cannot wander
  /// in (edit the board, import/export vocabulary, change behaviour).
  Future<bool> _passesGate(BuildContext context) async {
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        child: MathGate(onUnlocked: () => Navigator.of(context).pop(true)),
      ),
    );
    return unlocked == true;
  }

  /// Opens [screen] behind the parental math gate.
  Future<void> _openGated(BuildContext context, Widget screen) async {
    if (!await _passesGate(context) || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Exports the home board (with the parent's customizations) as a shareable
  /// `.json` vocabulary pack via the OS share sheet (ADR 0015), the receiving
  /// end of the Import row. Mirrors the board editor's share so Export is
  /// discoverable here too (clinical review: "no Export, what use is import?"). Folders
  /// are dropped and custom photos degrade to text-only (the exporter); the
  /// child's photos never leave the device. The temp file is deleted after.
  Future<void> _exportBoardPack(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    if (!await _passesGate(context) || !context.mounted) return;
    final boards = await ref.read(editableBoardsProvider.future);
    if (!context.mounted) return;
    if (boards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(l10n.shareVocabFailed),
        ),
      );
      return;
    }
    final board = boards.firstWhere(
      (b) => b.boardId == kHomeBoardId,
      orElse: () => boards.first,
    );
    final preview = BoardPackExporter.buildExportBoard(board);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shareVocabTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shareVocabBody),
            if (preview.photosAsTextOnly > 0) ...[
              const SizedBox(height: 12),
              Text(l10n.shareVocabPhotos(preview.photosAsTextOnly)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.shareVocabConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final languageCode = Localizations.localeOf(context).languageCode;
    // iPad/macOS require a popover anchor rect or share_plus throws; ignored on
    // iPhone/Android. Anchor to this screen's render box.
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    File? tempFile;
    try {
      final export = await BoardPackExporter().prepare(board);
      tempFile = export.file;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(export.file.path)],
          subject: board.boardNameFor(languageCode),
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            content: Text(l10n.shareVocabFailed),
          ),
        );
      }
    } finally {
      if (tempFile != null && tempFile.existsSync()) {
        try {
          await tempFile.delete();
        } catch (_) {/* best-effort */}
      }
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context, String url) async {
    final l10n = AppLocalizations.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(l10n.couldNotOpenLink),
      ),
    );
  }
}
