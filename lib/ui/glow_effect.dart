/// Glow visual wrapper for AAC button tiles (redesign).
///
/// A decorative paint layer OVER an existing tile. It never affects layout, so
/// a tile flipping from none to glowing cannot push neighbors or relayout. Four
/// treatments map to [GlowStyle] (plus an off switch):
///
/// * halo - amber ring + outer bloom + scale(1.02); pulses (2.2s) unless
///          reduced-motion, which downgrades it to a static halo
/// * ring - a crisp 4px inset amber ring
/// * lift - the tile raises 3px with a warm shadow and a 5px underline bar
/// * dot  - a 14px corner dot with a soft ring; no motion (calmest)
///
/// [level] (shimmer vs gold) scales the intensity; the cold-start shimmer keeps
/// the board feeling alive on day one while gold is earned over time.
library;

import 'package:flutter/material.dart';

import '../logic/logic.dart';
import 'theme/lighthouse_theme.dart';

/// Warm glow base / strong tones (handoff `--glow` / `--glow-strong`).
const Color kGlowGold = LhColors.glow;
const Color _glowStrong = LhColors.glowStrong;

class GlowEffect extends StatelessWidget {
  const GlowEffect({
    required this.level,
    required this.style,
    required this.child,
    super.key,
  });

  final GlowLevel level;
  final GlowStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (level == GlowLevel.none || !style.showsGlow) return child;
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final intensity = _intensityFor(level);
    return switch (style) {
      GlowStyle.halo => _HaloGlow(
          key: const ValueKey('glow.halo'),
          intensity: intensity,
          pulse: !reducedMotion,
          child: child,
        ),
      GlowStyle.ring => _RingGlow(
          key: const ValueKey('glow.ring'),
          intensity: intensity,
          child: child,
        ),
      GlowStyle.lift => _LiftGlow(
          key: const ValueKey('glow.lift'),
          intensity: intensity,
          child: child,
        ),
      GlowStyle.dot => _DotGlow(
          key: const ValueKey('glow.dot'),
          intensity: intensity,
          child: child,
        ),
      // off is handled by the showsGlow guard above; unreachable.
      GlowStyle.off => child,
    };
  }
}

double _intensityFor(GlowLevel level) => switch (level) {
      GlowLevel.gold => 1.0,
      GlowLevel.shimmer => 0.55,
      GlowLevel.none => 0.0,
    };

/// Amber ring + outer bloom + a gentle scale. Pulses when motion is allowed.
class _HaloGlow extends StatefulWidget {
  const _HaloGlow({
    required this.intensity,
    required this.pulse,
    required this.child,
    super.key,
  });

  final double intensity;
  final bool pulse;
  final Widget child;

  @override
  State<_HaloGlow> createState() => _HaloGlowState();
}

class _HaloGlowState extends State<_HaloGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LhMotion.haloPulse,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_HaloGlow old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Static (no pulse) sits at the trough; pulse breathes trough->peak.
        final t = widget.pulse ? _controller.value : 0.0;
        final bloomBlur = 16.0 + 12.0 * t; // 16 -> 28
        final bloomSpread = 2.0 + 6.0 * t; // 2 -> 8
        final bloomAlpha = (0.40 + 0.25 * t) * widget.intensity; // .40 -> .65
        return Transform.scale(
          scale: 1.02,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: LhRadii.tileR,
              boxShadow: [
                // Crisp amber ring.
                BoxShadow(
                  color: kGlowGold.withValues(alpha: widget.intensity),
                  spreadRadius: 3,
                  blurRadius: 0,
                ),
                // Outer bloom.
                BoxShadow(
                  color: kGlowGold.withValues(alpha: bloomAlpha),
                  spreadRadius: bloomSpread,
                  blurRadius: bloomBlur,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// A crisp 4px inset amber ring painted over the tile edge.
class _RingGlow extends StatelessWidget {
  const _RingGlow({required this.intensity, required this.child, super.key});

  final double intensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      // passthrough so the tile keeps its tight cell constraints (the ring is
      // a Positioned.fill overlay and must not relax the child's sizing).
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: LhRadii.tileR,
                border: Border.all(
                  color: _glowStrong.withValues(alpha: intensity),
                  width: 4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The tile raises 3px with a warm shadow and a 5px amber underline bar.
class _LiftGlow extends StatelessWidget {
  const _LiftGlow({required this.intensity, required this.child, super.key});

  final double intensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -3),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: LhRadii.tileR,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB45F1B).withValues(alpha: .30 * intensity),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: FractionallySizedBox(
                    widthFactor: 0.64,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: _glowStrong.withValues(alpha: intensity),
                        borderRadius: const BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
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

/// A quiet 14px corner dot with a soft ring. No motion: best for children
/// distracted by movement.
class _DotGlow extends StatelessWidget {
  const _DotGlow({required this.intensity, required this.child, super.key});

  final double intensity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        PositionedDirectional(
          top: 9,
          start: 9,
          child: IgnorePointer(
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _glowStrong.withValues(alpha: intensity),
                boxShadow: [
                  BoxShadow(
                    color: kGlowGold.withValues(alpha: .35 * intensity),
                    spreadRadius: 3,
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
