/// Contextual first-use tips (v7 handoff, ADR 0020).
///
/// A one-time, dismissible bubble shown the FIRST time a parent opens a powerful
/// screen, anchored to the real control there (title + body + "Got it"). The
/// per-tip "seen" flag is a SharedPreferences bool, so it shows once then never
/// again. Only ONE tip is on screen at a time (a new show clears the previous),
/// and it is cleared on navigation (each host clears it in dispose).
///
/// Visibility: the bubble is fully OPAQUE at rest; only the slide-in is animated
/// (and only when motion is allowed). Visibility is never gated on an opacity
/// animation, so the tip is readable even if the entrance does not play.
///
/// Anchored via the root Overlay using the target's GLOBAL rect, so it floats
/// correctly above both full screens and dialogs (e.g. the math gate).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import 'tour_controller.dart';

/// Holds the single active tip overlay entry and which tip "owns" it.
/// App-scoped (keepAlive).
class FirstUseTipController {
  OverlayEntry? _entry;
  String? _ownerKey;

  void _removeCurrent() {
    _entry?.remove();
    _entry = null;
    _ownerKey = null;
  }

  /// Shows the tip for [tipKey] anchored under [anchor], unless it has been seen
  /// before, the tour is active, or the anchor is not laid out. Tolerant of a
  /// missing SharedPreferences backend (just shows nothing) so it never throws
  /// on a hot path or in a host test.
  Future<void> maybeShow({
    required BuildContext context,
    required FirstUseTipsStore store,
    required String tipKey,
    required GlobalKey anchor,
    required String title,
    required String body,
    required String gotItLabel,
    required bool tourActive,
    required bool reduceMotion,
  }) async {
    if (tourActive) return;
    bool seen;
    try {
      seen = await store.seen(tipKey);
    } catch (_) {
      return; // no persistence available; do not show an un-persistable tip
    }
    if (seen || !context.mounted) return;
    // The host screen often loads asynchronously (editableBoards, favourites,
    // custom buttons): on the first frame it is a spinner and the anchor is not
    // in the tree yet. Poll for the anchor across a bounded number of frames so
    // the tip still appears once the real content lays out, then give up (e.g.
    // a custom-buttons screen that never shows its empty-state button). ~5s at
    // 60fps: a cold editor load exceeds a shorter budget.
    _place(
      context: context,
      store: store,
      tipKey: tipKey,
      anchor: anchor,
      title: title,
      body: body,
      gotItLabel: gotItLabel,
      reduceMotion: reduceMotion,
      attemptsLeft: 300,
    );
  }

  void _place({
    required BuildContext context,
    required FirstUseTipsStore store,
    required String tipKey,
    required GlobalKey anchor,
    required String title,
    required String body,
    required String gotItLabel,
    required bool reduceMotion,
    required int attemptsLeft,
  }) {
    if (!context.mounted) return;
    final box = anchor.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(context);
    if (box is RenderBox && box.hasSize && overlay != null) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      _removeCurrent();
      final entry = OverlayEntry(
        builder: (_) => _TipBubble(
          anchor: rect,
          title: title,
          body: body,
          gotItLabel: gotItLabel,
          reduceMotion: reduceMotion,
          onDismiss: () {
            if (_ownerKey == tipKey) _removeCurrent();
            store.markSeen(tipKey);
          },
        ),
      );
      _entry = entry;
      _ownerKey = tipKey;
      overlay.insert(entry);
      return;
    }
    if (attemptsLeft <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _place(
          context: context,
          store: store,
          tipKey: tipKey,
          anchor: anchor,
          title: title,
          body: body,
          gotItLabel: gotItLabel,
          reduceMotion: reduceMotion,
          attemptsLeft: attemptsLeft - 1,
        ));
  }

  /// Removes the current tip without marking it seen. A host clears it on
  /// navigation by passing its own [ownerTipKey]; that only removes the tip if
  /// THIS host still owns it, so a screen tearing down late (e.g. a math-gate
  /// dialog finishing its exit animation after the next screen has already
  /// shown its own tip) cannot nuke the newer screen's tip. A null key force
  /// clears (app teardown).
  void dismiss({String? ownerTipKey}) {
    if (ownerTipKey == null || ownerTipKey == _ownerKey) _removeCurrent();
  }
}

final firstUseTipControllerProvider =
    Provider<FirstUseTipController>((ref) {
  final c = FirstUseTipController();
  ref.onDispose(c.dismiss);
  return c;
});

/// Wraps a screen body, owns a stable anchor [GlobalKey], and shows the tip on
/// first build (clearing it on navigation). The screen attaches the supplied
/// key to the control the tip should point at.
class FirstUseTipHost extends ConsumerStatefulWidget {
  const FirstUseTipHost({
    required this.tipKey,
    required this.title,
    required this.body,
    required this.builder,
    super.key,
  });

  final String tipKey;
  final String title;
  final String body;
  final Widget Function(BuildContext context, GlobalKey anchorKey) builder;

  @override
  ConsumerState<FirstUseTipHost> createState() => _FirstUseTipHostState();
}

class _FirstUseTipHostState extends ConsumerState<FirstUseTipHost> {
  final GlobalKey _anchor = GlobalKey();
  late final FirstUseTipController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(firstUseTipControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.maybeShow(
        context: context,
        store: ref.read(firstUseTipsStoreProvider),
        tipKey: widget.tipKey,
        anchor: _anchor,
        title: widget.title,
        body: widget.body,
        gotItLabel: AppLocalizations.of(context).tipGotIt,
        tourActive: ref.read(tourControllerProvider).active,
        reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
      );
    });
  }

  @override
  void dispose() {
    _controller.dismiss(ownerTipKey: widget.tipKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _anchor);
}

class _TipBubble extends StatefulWidget {
  const _TipBubble({
    required this.anchor,
    required this.title,
    required this.body,
    required this.gotItLabel,
    required this.reduceMotion,
    required this.onDismiss,
  });

  final Rect anchor;
  final String title;
  final String body;
  final String gotItLabel;
  final bool reduceMotion;
  final VoidCallback onDismiss;

  @override
  State<_TipBubble> createState() => _TipBubbleState();
}

class _TipBubbleState extends State<_TipBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = 330.0.clamp(0.0, size.width - 32);
    final a = widget.anchor;
    final left = (a.center.dx - w / 2).clamp(16.0, size.width - w - 16);

    // Below the anchor by default; flip above if there is not room below (a
    // generous 180pt estimate covers title + body + button).
    const estH = 180.0;
    final placeAbove =
        a.bottom + 14 + estH > size.height - 12 && a.top - 14 - estH > 12;
    final arrowX = (a.center.dx - left).clamp(24.0, w - 24);

    final bubble = Material(
      type: MaterialType.transparency,
      child: _Bubble(
        width: w.toDouble(),
        arrowX: arrowX.toDouble(),
        arrowOnTop: !placeAbove,
        title: widget.title,
        body: widget.body,
        gotItLabel: widget.gotItLabel,
        onDismiss: widget.onDismiss,
      ),
    );

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Slide-in is translateY only; opacity is always 1 (visibility note).
        final slide = widget.reduceMotion
            ? 0.0
            : (1 - Curves.easeOut.transform(_c.value)) * 8.0;
        if (placeAbove) {
          return Positioned(
            left: left.toDouble(),
            bottom: size.height - (a.top - 14) - slide,
            width: w.toDouble(),
            child: child!,
          );
        }
        return Positioned(
          left: left.toDouble(),
          top: a.bottom + 14 + slide,
          width: w.toDouble(),
          child: child!,
        );
      },
      child: bubble,
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.width,
    required this.arrowX,
    required this.arrowOnTop,
    required this.title,
    required this.body,
    required this.gotItLabel,
    required this.onDismiss,
  });

  final double width;
  final double arrowX;
  final bool arrowOnTop;
  final String title;
  final String body;
  final String gotItLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      decoration: BoxDecoration(
        color: LhColors.brown,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: LhShadows.pop,
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Atkinson Hyperlegible',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontFamily: 'Atkinson Hyperlegible',
              fontSize: 16,
              height: 1.4,
              color: Colors.white.withValues(alpha: .92),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('tip_gotit'),
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: .18),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: Text(gotItLabel),
            ),
          ),
        ],
      ),
    );

    final arrow = Padding(
      padding: EdgeInsetsDirectional.only(start: (arrowX - 8).clamp(0, width)),
      child: Transform.rotate(
        angle: 0.785398, // 45deg
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: LhColors.brown,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: arrowOnTop
          ? [Transform.translate(offset: const Offset(0, 5), child: arrow), card]
          : [card, Transform.translate(offset: const Offset(0, -5), child: arrow)],
    );
  }
}
