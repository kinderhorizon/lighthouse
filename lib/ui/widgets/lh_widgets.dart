/// Shared redesign UI primitives.
///
/// Reusable building blocks transcribed from the designer handoff: the app bar
/// (centered title + optional bottom hairline), section labels, the 76px
/// settings row, grouped list cards, and the empty-state medallion. Screens
/// compose these so spacing, type, and motion stay identical everywhere.
library;

import 'package:flutter/material.dart';

import '../theme/lighthouse_theme.dart';

/// App bar matching the handoff chrome: cream ground, no shadow, optional
/// 1px bottom hairline (used on every pushed detail screen), centered or
/// leading title.
PreferredSizeWidget lhAppBar(
  BuildContext context, {
  String? title,
  bool centerTitle = true,
  bool bordered = true,
  List<Widget> actions = const [],
  Widget? leading,
  double? leadingWidth,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    title: title == null ? null : Text(title),
    centerTitle: centerTitle,
    leading: leading,
    // Default leading slot is ~56pt: a text leading ("Cancel") wraps. Widen it
    // when the caller passes a text button.
    leadingWidth: leadingWidth,
    automaticallyImplyLeading: automaticallyImplyLeading,
    actions: actions,
    bottom: bordered
        ? const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: LhColors.line),
          )
        : null,
  );
}

/// Uppercase amber-deep section label, 14/700 with wide tracking.
class LhSectionLabel extends StatelessWidget {
  const LhSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(28, 22, 28, 8),
      child: Text(text.toUpperCase(), style: LhText.sectionLabel),
    );
  }
}

/// Trailing affordance on a settings row.
enum LhRowTrailing { chevron, external, none }

/// A 76px tappable settings row: leading icon, title over optional subtitle,
/// trailing chevron / external-link glyph. Hover/press tints follow the
/// handoff (cream-2 hover, line pressed).
class LhSettingsRow extends StatelessWidget {
  const LhSettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing = LhRowTrailing.chevron,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final LhRowTrailing trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: LhColors.cream2,
        highlightColor: LhColors.line,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LhSpace.rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Icon(icon, size: 30, color: LhColors.ink2),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: LhText.rowTitle),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: LhText.rowSubtitle),
                      ],
                    ],
                  ),
                ),
                _trailing(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trailing() {
    switch (trailing) {
      case LhRowTrailing.chevron:
        return const Icon(Icons.chevron_right, size: 24, color: LhColors.ink3);
      case LhRowTrailing.external:
        return const Icon(Icons.open_in_new, size: 22, color: LhColors.ink3);
      case LhRowTrailing.none:
        return const SizedBox.shrink();
    }
  }
}

/// A 76px settings row whose trailing control is a Material switch.
class LhSwitchRow extends StatelessWidget {
  const LhSwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        hoverColor: LhColors.cream2,
        highlightColor: LhColors.line,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LhSpace.rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Icon(icon, size: 30, color: LhColors.ink2),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: LhText.rowTitle),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: LhText.rowSubtitle),
                      ],
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A grouped list card: a rounded surface panel with a hairline border that
/// clips its children and draws dividers between them.
class LhListCard extends StatelessWidget {
  const LhListCard({required this.children, this.margin, super.key});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: LhColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: LhColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A short help paragraph (ink-2, 17px), the standard lead-in on detail
/// screens.
class LhHelpText extends StatelessWidget {
  const LhHelpText(this.text, {this.padding, super.key});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.fromLTRB(28, 16, 28, 16),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Atkinson Hyperlegible',
          fontSize: 17,
          height: 1.45,
          color: LhColors.ink2,
        ),
      ),
    );
  }
}

/// The 138px squircle "medallion" used by empty states: a radial cream->white
/// gradient with an inset hairline, a soft drop shadow, a faint amber halo
/// behind, and a centered icon. Pops in (scale) unless reduced-motion.
class LhMedallion extends StatelessWidget {
  const LhMedallion({required this.icon, this.iconColor = LhColors.amber, super.key});

  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final art = SizedBox(
      width: 158,
      height: 158,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft amber halo behind.
          Container(
            width: 158,
            height: 158,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LhColors.amber.withValues(alpha: .16),
                  LhColors.amber.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Container(
            width: 138,
            height: 138,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(40)),
              gradient: const RadialGradient(
                center: Alignment(-0.36, -0.52),
                radius: 1.0,
                colors: [Color(0xFFFFFFFF), LhColors.cream2],
                stops: [0.0, 0.78],
              ),
              border: Border.all(color: LhColors.line),
              boxShadow: [
                BoxShadow(
                  color: LhColors.inkAlpha(.10),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(icon, size: 62, color: iconColor),
          ),
        ],
      ),
    );
    if (reducedMotion) return art;
    return _PopIn(child: art);
  }
}

/// The shared empty-state layout: a centered medallion, a kind headline, one
/// sentence of guidance, and an optional action below.
class LhEmptyState extends StatelessWidget {
  const LhEmptyState({
    required this.icon,
    required this.headline,
    required this.body,
    this.iconColor = LhColors.amber,
    this.action,
    super.key,
  });

  final IconData icon;
  final String headline;
  final String body;
  final Color iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LhMedallion(icon: icon, iconColor: iconColor),
            const SizedBox(height: 22),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Atkinson Hyperlegible',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: LhColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Atkinson Hyperlegible',
                  fontSize: 18,
                  height: 1.45,
                  color: LhColors.ink2,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 28),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _PopIn extends StatefulWidget {
  const _PopIn({required this.child});

  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: LhMotion.ease);
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.0).animate(curved),
      child: FadeTransition(opacity: curved, child: widget.child),
    );
  }
}
