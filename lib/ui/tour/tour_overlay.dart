/// The coach-mark overlay (ADR 0020): a dimming layer with a rounded spotlight
/// cutout over the current step's target, plus a caption card with progress and
/// Skip / Back / Next. Mounted full-screen above the board Scaffold; renders
/// nothing when the tour is inactive.
///
/// Board-resident steps spotlight a real widget (measured from its GlobalKey);
/// steps whose target lives on a gated screen render a centred card with no
/// spotlight (TourTarget.none), exactly as the prototype engine does when a
/// target is absent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/lighthouse_theme.dart';
import 'tour_controller.dart';

class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key});

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay> {
  Rect? _rect;

  Rect? _measure(TourTarget target) {
    final key = switch (target) {
      TourTarget.board => tourBoardKey,
      TourTarget.sentence => tourSentenceKey,
      TourTarget.arrange => tourArrangeKey,
      TourTarget.settings => tourSettingsKey,
      TourTarget.none => null,
    };
    final ctx = key?.currentContext;
    final ro = ctx?.findRenderObject();
    if (ro is RenderBox && ro.hasSize) {
      return ro.localToGlobal(Offset.zero) & ro.size;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tour = ref.watch(tourControllerProvider);
    if (!tour.active) return const SizedBox.shrink();

    final step = tour.step;
    // Re-measure after layout so the spotlight tracks the real widget (and any
    // rotation / size change). setState only on a real change to avoid loops.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final r = _measure(step.target);
      if (r != _rect) setState(() => _rect = r);
    });

    final l10n = AppLocalizations.of(context);
    final controller = ref.read(tourControllerProvider.notifier);
    final size = MediaQuery.sizeOf(context);
    final hole = step.target == TourTarget.none ? null : _rect;

    // Card goes opposite the spotlight: target in the top half -> card at the
    // bottom, target in the bottom half -> card at the top, no target -> centre.
    final Alignment cardAlign;
    if (hole == null) {
      cardAlign = Alignment.center;
    } else if (hole.center.dy < size.height / 2) {
      cardAlign = Alignment.bottomCenter;
    } else {
      cardAlign = Alignment.topCenter;
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Scrim + cutout. A bare GestureDetector absorbs taps so the board
          // behind cannot be operated mid-tour (modal; no dismiss-on-scrim).
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(painter: _ScrimPainter(hole)),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: cardAlign,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: _CaptionCard(
                    progress: l10n.tourProgress(tour.index + 1, kTourSteps.length),
                    title: step.titleOf(l10n),
                    body: step.bodyOf(l10n),
                    isFirst: tour.isFirst,
                    isLast: tour.isLast,
                    onSkip: controller.stop,
                    onBack: controller.back,
                    onNext: controller.next,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionCard extends StatelessWidget {
  const _CaptionCard({
    required this.progress,
    required this.title,
    required this.body,
    required this.isFirst,
    required this.isLast,
    required this.onSkip,
    required this.onBack,
    required this.onNext,
  });

  final String progress;
  final String title;
  final String body;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        boxShadow: LhShadows.pop,
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(progress.toUpperCase(), style: LhText.sectionLabel),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Atkinson Hyperlegible',
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: LhColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: LhText.body.copyWith(color: LhColors.ink2)),
          const SizedBox(height: 16),
          Row(
            children: [
              // Expanded (not Spacer) so the row width equals its constraints
              // exactly and the action buttons can never overflow a narrow card.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const ValueKey('tour_skip'),
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      l10n.tourSkip,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (!isFirst) ...[
                FilledButton.tonal(
                  key: const ValueKey('tour_back'),
                  onPressed: onBack,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: Text(l10n.back),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton(
                key: const ValueKey('tour_next'),
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                child: Text(isLast ? l10n.tourFinish : l10n.next),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.hole);

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    // rgba(36,31,27,.62) from the handoff.
    final dim = Paint()..color = const Color(0x9E241F1B);
    final full = Offset.zero & size;
    if (hole == null) {
      canvas.drawRect(full, dim);
      return;
    }
    final rr = RRect.fromRectAndRadius(
        hole!.inflate(8), const Radius.circular(18));
    final path = Path()
      ..addRect(full)
      ..addRRect(rr)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dim);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = LhColors.glowStrong;
    canvas.drawRRect(rr, ring);
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
