/// Onboarding flow shell.
///
/// Holds the onboarding screens in a PageView, plus a fixed bottom navigation
/// bar with Back and Next / Done buttons. Each screen is individually
/// skippable; Done is available from anywhere. The Wi-Fi-context step is added
/// only on platforms that read Wi-Fi context (ADR 0016). See ADR 0003 §
/// Onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../tour/tour_controller.dart';
import 'screens/grid_familiarization_screen.dart';
import 'screens/home_label_screen.dart';
import 'screens/privacy_claim_screen.dart';
import 'screens/wifi_context_screen.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pageController = PageController();
  int _page = 0;

  /// Captured once (late final) so the page list is stable across rebuilds.
  /// The Wi-Fi-context step is included only where the platform actually reads
  /// Wi-Fi context (Android, ADR 0016); on iOS it is omitted and the bandit
  /// runs on wifi_UNKNOWN.
  late final List<Widget> _pages = [
    const GridFamiliarizationScreen(),
    const HomeLabelScreen(),
    if (ref.read(wifiSourceProvider).usesWifiContext) const WifiContextScreen(),
    const PrivacyClaimScreen(),
  ];

  bool get _isLastPage => _page == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingNotifierProvider.notifier).markComplete();
  }

  /// "Take the quick tour" (last screen): flag the tour to start, then complete
  /// onboarding. The board reads the flag on mount and starts the tour
  /// (ADR 0020).
  Future<void> _takeTour() async {
    ref.read(tourPendingStartProvider.notifier).state = true;
    await ref.read(onboardingNotifierProvider.notifier).markComplete();
  }

  void _next() {
    if (_isLastPage) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _back() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StepDots(current: _page, total: _pages.length),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: _pages,
              ),
            ),
            _NavBar(
              isFirst: _page == 0,
              isLast: _isLastPage,
              onBack: _back,
              onNext: _next,
              onDone: _finish,
              onTakeTour: _takeTour,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: AnimatedContainer(
              duration: LhMotion.medium,
              curve: LhMotion.ease,
              width: active ? 30 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: active ? LhColors.amber : LhColors.line2,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.isFirst,
    required this.isLast,
    required this.onBack,
    required this.onNext,
    required this.onDone,
    required this.onTakeTour,
  });

  final bool isFirst;
  final bool isLast;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onDone;
  final VoidCallback onTakeTour;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LhColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
      child: Row(
        children: [
          if (!isFirst)
            TextButton(onPressed: onBack, child: Text(l10n.back))
          else
            const SizedBox.shrink(),
          const Spacer(),
          // Done is available on EVERY screen (ADR 0003 § Onboarding): a parent
          // can finish at any point. Before the last screen it reads "Skip"
          // (text) beside the brown primary "Next"; the last screen's primary
          // is "Start using Lighthouse".
          if (!isLast) ...[
            TextButton(onPressed: onDone, child: Text(l10n.skip)),
            const SizedBox(width: 8),
            FilledButton(onPressed: onNext, child: Text(l10n.next)),
          ] else ...[
            // End of first run: offer the guided tour (ADR 0020). "Skip, go to
            // the board" just completes onboarding; "Take the quick tour"
            // completes it and starts the tour on the board.
            Flexible(
              child: FilledButton.tonal(
                onPressed: onDone,
                child: Text(
                  l10n.tourSkipToBoard,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FilledButton(
                onPressed: onTakeTour,
                child: Text(
                  l10n.tourTakeQuick,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
