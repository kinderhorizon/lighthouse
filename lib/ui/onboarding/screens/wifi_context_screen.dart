/// Onboarding Wi-Fi-context step (ADR 0016), redesign.
///
/// The single, deliberate, parent-facing moment where Lighthouse asks for the
/// permission it needs to read the (scrambled) Wi-Fi network name for the
/// bandit's place context. The request happens here and NOWHERE on the child's
/// tap path, so the OS Location dialog never appears mid-use.
///
/// Shown only where [WifiSource.usesWifiContext] is true (Android). On iOS this
/// screen is omitted and the bandit runs on `wifi_UNKNOWN`. Declining is fine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/state.dart';
import '../../theme/lighthouse_theme.dart';

class WifiContextScreen extends ConsumerStatefulWidget {
  const WifiContextScreen({super.key});

  @override
  ConsumerState<WifiContextScreen> createState() => _WifiContextScreenState();
}

class _WifiContextScreenState extends ConsumerState<WifiContextScreen> {
  /// null = not yet asked; true/false = the outcome of the one request.
  bool? _granted;

  Future<void> _request() async {
    final granted =
        await ref.read(wifiSourceProvider).requestWifiContextPermission();
    if (!mounted) return;
    setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingWifiTitle, style: LhText.display),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(l10n.onboardingWifiBody, style: LhText.lede),
          ),
          const SizedBox(height: 28),
          if (_granted == null)
            FilledButton(
              onPressed: _request,
              child: Text(l10n.onboardingWifiAllow),
            )
          else
            Row(
              children: [
                Icon(
                  _granted! ? Icons.check_circle_rounded : Icons.info_outline,
                  color: _granted! ? LhColors.good : LhColors.ink2,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _granted!
                        ? l10n.onboardingWifiGranted
                        : l10n.onboardingWifiDenied,
                    style: LhText.body,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
