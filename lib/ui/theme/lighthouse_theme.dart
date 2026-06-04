/// Lighthouse AAC design system (redesign, 2026-06).
///
/// The single source of truth for color, type, shape, elevation, spacing, and
/// motion. Every screen reads from here so the warm, calm, accessibility-first
/// look stays consistent and is changed in one place. Values are transcribed
/// from the designer handoff (`design_handoff_lighthouse_aac/prototype/app.css`)
/// which is the styling source of truth.
///
/// Typography is Atkinson Hyperlegible (Braille Institute, OFL), chosen for
/// maximum letter distinction. Arabic resolves to Cairo (see [LocaleRegistry]);
/// Cairo is always a fallback so mixed-script text never falls to a platform
/// default.
library;

import 'package:flutter/material.dart';

/// Warm-neutral ground, ink, brand, glow, and feedback colors. Fitzgerald
/// category fills live in board `color_key` JSON, not here (they are clinical
/// data, swappable per board); the matching tile EDGE colors are derived in
/// `fitzgerald_palette.dart`.
abstract final class LhColors {
  // Warm neutral ground.
  static const cream = Color(0xFFFAF4EA); // app background
  static const cream2 = Color(0xFFF4EBDB); // grouped / pressed ground
  static const surface = Color(0xFFFFFDF8); // cards, dialogs, fields
  static const line = Color(0xFFEADFCE); // hairlines
  static const line2 = Color(0xFFE0D3BE); // stronger dividers / field borders

  // Ink.
  static const ink = Color(0xFF2B2521); // primary text
  static const ink2 = Color(0xFF6E655B); // secondary text
  static const ink3 = Color(0xFF9C9183); // tertiary / placeholder

  // Brand.
  static const amber = Color(0xFFE8873C); // accent / highlight / focus
  static const amberDeep = Color(0xFFB45F1B); // accessible amber text on cream
  static const amberTint = Color(0xFFFBE7D2); // selected pill / tonal fill
  static const amberLine = Color(0xFFE9C49A);
  static const brown = Color(0xFF6E3F22); // primary action (white text, AA)
  static const brownPress = Color(0xFF56301A);
  static const navy = Color(0xFF1F3A4A); // logo ink, used sparingly

  // Glow (next-likely-word).
  static const glow = Color(0xFFF2A53A);
  static const glowStrong = Color(0xFFE8873C);

  // Feedback.
  static const good = Color(0xFF2F7D55);
  static const goodBg = Color(0xFFDCEFE2);

  /// Ink at a given opacity, for hairline shadows.
  static Color inkAlpha(double a) => ink.withValues(alpha: a);
}

/// Corner radii (logical px).
abstract final class LhRadii {
  static const tile = 22.0;
  static const card = 24.0;
  static const field = 16.0;
  static const dialog = 28.0;
  static const pill = 999.0;

  static const tileR = BorderRadius.all(Radius.circular(tile));
  static const cardR = BorderRadius.all(Radius.circular(card));
  static const fieldR = BorderRadius.all(Radius.circular(field));
  static const dialogR = BorderRadius.all(Radius.circular(dialog));
}

/// Spacing scale (logical px).
abstract final class LhSpace {
  static const screenPad = 28.0; // screen horizontal padding
  static const boardGutter = 14.0; // gap between tiles
  static const rowMinHeight = 76.0; // settings row height
  static const buttonMinHeight = 56.0; // primary button height
  static const iconButton = 56.0; // 56x56 icon button
}

/// Elevation as explicit shadow lists (Material elevation is not used; the
/// design specifies precise warm-ink shadows).
abstract final class LhShadows {
  static final tileRest = <BoxShadow>[
    BoxShadow(color: LhColors.inkAlpha(.04), blurRadius: 1, offset: const Offset(0, 1)),
    BoxShadow(color: LhColors.inkAlpha(.05), blurRadius: 7, offset: const Offset(0, 3)),
  ];
  static final tileHover = <BoxShadow>[
    BoxShadow(color: LhColors.inkAlpha(.06), blurRadius: 5, offset: const Offset(0, 2)),
    BoxShadow(color: LhColors.inkAlpha(.09), blurRadius: 20, offset: const Offset(0, 10)),
  ];
  static final card = <BoxShadow>[
    BoxShadow(color: LhColors.inkAlpha(.06), blurRadius: 2, offset: const Offset(0, 1)),
    BoxShadow(color: LhColors.inkAlpha(.05), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static final pop = <BoxShadow>[
    BoxShadow(color: LhColors.inkAlpha(.20), blurRadius: 48, offset: const Offset(0, 18)),
  ];
  static final primaryButton = <BoxShadow>[
    BoxShadow(
      color: LhColors.brown.withValues(alpha: .22),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}

/// Motion tokens. All entrance / pulse motion is gated behind reduced-motion
/// at the call site (MediaQuery.disableAnimations).
abstract final class LhMotion {
  static const ease = Cubic(.2, .7, .3, 1);
  static const fast = Duration(milliseconds: 140);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 340);
  static const haloPulse = Duration(milliseconds: 2200);
}

/// Type scale. Sizes are logical px (the handoff specifies px on an iPad
/// artboard; Flutter logical px match at the 11" portrait reference).
abstract final class LhText {
  static const _f = 'Atkinson Hyperlegible';

  static const display = TextStyle(
    fontFamily: _f,
    fontSize: 38,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.76,
    color: LhColors.ink,
  );
  static const screenTitle = TextStyle(
    fontFamily: _f,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.24,
    color: LhColors.ink,
  );
  static const dialogTitle = TextStyle(
    fontFamily: _f,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.26,
    color: LhColors.ink,
  );
  static const rowTitle = TextStyle(
    fontFamily: _f,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: LhColors.ink,
  );
  static const body = TextStyle(
    fontFamily: _f,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: LhColors.ink,
  );
  static const lede = TextStyle(
    fontFamily: _f,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: LhColors.ink2,
  );
  static const tileLabel = TextStyle(
    fontFamily: _f,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -0.18,
    color: LhColors.ink,
  );
  static const rowSubtitle = TextStyle(
    fontFamily: _f,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: LhColors.ink2,
  );
  static const sectionLabel = TextStyle(
    fontFamily: _f,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.12, // 0.08em
    color: LhColors.amberDeep,
  );
  static const caption = TextStyle(
    fontFamily: _f,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: LhColors.ink3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Builds the app [ThemeData]. [fontFamily] is the resolved primary face
/// (Atkinson Hyperlegible normally, Cairo under Arabic); Cairo is always a
/// fallback so Arabic glyphs render from a bundled face.
ThemeData buildLighthouseTheme({required String fontFamily}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: LhColors.amber,
    brightness: Brightness.light,
  ).copyWith(
    primary: LhColors.brown,
    onPrimary: Colors.white,
    secondary: LhColors.amber,
    onSecondary: Colors.white,
    secondaryContainer: LhColors.amberTint,
    onSecondaryContainer: LhColors.amberDeep,
    tertiary: LhColors.good,
    onTertiary: Colors.white,
    tertiaryContainer: LhColors.goodBg,
    onTertiaryContainer: LhColors.good,
    surface: LhColors.surface,
    onSurface: LhColors.ink,
    surfaceContainerHighest: LhColors.cream2,
    onSurfaceVariant: LhColors.ink2,
    outline: LhColors.line2,
    outlineVariant: LhColors.line,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LhColors.cream,
    canvasColor: LhColors.cream,
    fontFamily: fontFamily,
    fontFamilyFallback: const ['Cairo'],
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: LhColors.ink,
      displayColor: LhColors.ink,
      fontFamily: fontFamily,
    ),
    dividerColor: LhColors.line,
    dividerTheme: const DividerThemeData(
      color: LhColors.line,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: LhColors.cream,
      foregroundColor: LhColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: LhText.screenTitle,
      iconTheme: IconThemeData(color: LhColors.ink, size: 28),
    ),
    iconTheme: const IconThemeData(color: LhColors.ink2, size: 28),
    // FilledButton -> primary (brown); FilledButton.tonal -> secondaryContainer
    // (amber-tint). We set only shape/size/type here so the tonal default keeps
    // its own fill (setting backgroundColor here would flatten tonal to filled).
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, LhSpace.buttonMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Atkinson Hyperlegible',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LhColors.amberDeep,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Atkinson Hyperlegible',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? LhColors.amberTint
                : LhColors.surface),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? LhColors.amberDeep
                : LhColors.ink2),
        side: const WidgetStatePropertyAll(
          BorderSide(color: LhColors.line2, width: 1.5),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: 'Atkinson Hyperlegible',
          fontSize: 17,
          fontWeight: FontWeight.w700,
        )),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: LhColors.surface,
      contentPadding: EdgeInsets.all(18),
      hintStyle: TextStyle(color: LhColors.ink3, fontStyle: FontStyle.italic),
      labelStyle: TextStyle(color: LhColors.ink2),
      floatingLabelStyle: TextStyle(color: LhColors.amberDeep),
      counterStyle: LhText.caption,
      border: OutlineInputBorder(
        borderRadius: LhRadii.fieldR,
        borderSide: BorderSide(color: LhColors.line2, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: LhRadii.fieldR,
        borderSide: BorderSide(color: LhColors.line2, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: LhRadii.fieldR,
        borderSide: BorderSide(color: LhColors.amber, width: 2),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? LhColors.brown
              : LhColors.line2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: LhColors.ink2,
      textColor: LhColors.ink,
      titleTextStyle: TextStyle(
        fontFamily: 'Atkinson Hyperlegible',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: LhColors.ink,
      ),
      subtitleTextStyle: LhText.rowSubtitle,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: LhColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: LhRadii.dialogR),
      titleTextStyle: LhText.dialogTitle,
      contentTextStyle: LhText.body,
    ),
    cardTheme: const CardThemeData(
      color: LhColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: LhRadii.cardR),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LhColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'Atkinson Hyperlegible',
        fontSize: 16,
        color: LhColors.cream,
      ),
      actionTextColor: LhColors.amberTint,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: LhColors.brown,
    ),
  );
}
