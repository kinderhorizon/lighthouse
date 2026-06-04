/// About screen (redesign).
///
/// Informational only: the Lighthouse mark, attribution, a short mission line,
/// and a card with the website link-out and the version. Viewing is ungated.
///
/// The single link out of the app (to kinderhorizon.org) sits behind the math
/// gate, which doubles as the parental gate App Store rules require for an app
/// with a child audience. The label is deliberately neutral ("Visit
/// kinderhorizon.org"): there is NO "Donate" or "Support" wording in-app.
/// Donations are never collected in the app; the ask lives entirely on the
/// website, which both stores allow.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../theme/lighthouse_theme.dart';
import '../widgets/lh_widgets.dart';
import 'math_gate.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final Uri _khfUri = Uri.parse('https://kinderhorizon.org');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: lhAppBar(context, title: l10n.aboutTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 40, 0, 28),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Image.asset(
                    'assets/brand/lighthouse-mark.png',
                    height: 96,
                    semanticLabel: 'Lighthouse AAC',
                    errorBuilder: (context, error, stack) =>
                        const SizedBox(height: 96),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lighthouse AAC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Atkinson Hyperlegible',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: LhColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.aboutTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Atkinson Hyperlegible',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: LhColors.amberDeep,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      l10n.aboutBody,
                      textAlign: TextAlign.center,
                      style: LhText.body.copyWith(color: LhColors.ink2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            LhListCard(
              children: [
                LhSettingsRow(
                  icon: Icons.public_rounded,
                  title: l10n.visitWebsite,
                  subtitle: l10n.visitWebsiteSubtitle,
                  trailing: LhRowTrailing.external,
                  onTap: () => _openWebsite(context),
                ),
                LhSettingsRow(
                  icon: Icons.workspace_premium_outlined,
                  title: l10n.aboutLicences,
                  subtitle: l10n.aboutLicencesSubtitle,
                  onTap: () => _openLicences(context),
                ),
                const _VersionRow(),
              ],
            ),
            const SizedBox(height: 26),
            const _Credits(),
          ],
        ),
      ),
    );
  }

  /// Opens Flutter's licence page, which auto-aggregates every Dart/Flutter
  /// package licence plus the entries registered at startup (the bundled fonts
  /// and the Google Cloud TTS provenance notice, lib/config/licenses.dart).
  /// Ungated, like the rest of About (it leaves nothing and reaches no network).
  Future<void> _openLicences(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showLicensePage(
      context: context,
      applicationName: 'Lighthouse AAC',
      applicationVersion: info.version,
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    // Parental gate before leaving the app (App Store requirement for a child
    // audience). The same math gate used for the Advanced tier.
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        child: MathGate(onUnlocked: () => Navigator.of(ctx).pop(true)),
      ),
    );
    if (unlocked != true) return;

    final ok = await launchUrl(_khfUri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(AppLocalizations.of(context).couldNotOpenBrowser),
      ),
    );
  }
}

/// ARASAAC picture-symbol attribution. The CC BY-NC-SA license requires this
/// credit to be VISIBLE in the app (ADR 0001 / LICENSES/ARASAAC.md). The label
/// is localized; the credit string itself is a verbatim license term and is
/// NOT translated or altered (a documented hardcoded-string exception, like the
/// contact-address constants).
class _Credits extends StatelessWidget {
  const _Credits();

  static const String _arasaacCredit =
      'Symbols Author: Sergio Palao. Origin: ARASAAC (https://arasaac.org). '
      'License: CC (BY-NC-SA). Owner: Government of Aragón (Spain).';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            l10n.aboutCredits,
            textAlign: TextAlign.center,
            style: LhText.sectionLabel,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const Text(
              _arasaacCredit,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Atkinson Hyperlegible',
                fontSize: 15,
                height: 1.45,
                color: LhColors.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info == null
            ? l10n.version
            : l10n.versionLabel(info.version, info.buildNumber);
        return LhSettingsRow(
          icon: Icons.info_outline_rounded,
          title: version,
          subtitle: l10n.aboutLicence,
          trailing: LhRowTrailing.none,
        );
      },
    );
  }
}
