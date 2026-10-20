import 'package:flutter/material.dart';
import '../theme/lighthouse_theme.dart';

/// Reusable NūriTalk brand logo and app header widget.
///
/// Features:
/// - Bundled lighthouse emblem with high-contrast text mark.
/// - RTL-safe brand preservation: "Nūri" (deep ocean navy) + "Talk" (luminous cyan).
/// - Scalable heights for headers, cards, dialogs, and splash screens.
class NuriTalkBrandLogo extends StatelessWidget {
  const NuriTalkBrandLogo({
    super.key,
    this.height = 36.0,
    this.showText = true,
    this.fontSize = 22.0,
  });

  final double height;
  final bool showText;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Keep brand mark strictly LTR regardless of active device/app locale
    return Directionality(
      textDirection: TextDirection.ltr,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/brand/nuritalk_emblem.png',
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/brand/nuritalk_logo.png',
                height: height,
                fit: BoxFit.contain,
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'Atkinson Hyperlegible',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  children: const [
                    TextSpan(
                      text: 'Nūri',
                      style: TextStyle(color: LhColors.nuriNavy),
                    ),
                    TextSpan(
                      text: 'Talk',
                      style: TextStyle(color: LhColors.nuriTeal),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
