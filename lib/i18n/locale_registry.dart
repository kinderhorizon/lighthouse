/// Locale registry: the single source of truth for every supported language.
///
/// Per ADR 0008, adding a language must be a DATA operation, not a code edit.
/// `supportedLocales`, the `localeResolutionCallback`, the TTS engine picker,
/// the locale picker UI, and the localization tests all derive from the table
/// below. Adding a locale = one [LocaleSpec] entry here, an `app_<code>.arb`
/// file, the `label_<code>` / `voice_out_<code>` board keys, and (where the
/// TTS strategy requires it) bundled audio clips. No widget or logic edits.
///
/// INVARIANT (ADR 0008): there is no `if (locale == 'ar')` anywhere in the
/// codebase. Direction-dependent behavior keys off [LocaleSpec.direction] /
/// `Directionality.of(context)`, never a hardcoded language code.
library;

import 'dart:ui' show Locale, PlatformDispatcher, TextDirection;

/// How a locale's audio is produced. The core vocabulary is a small finite
/// set, so locales whose platform may lack a system voice (e.g. Arabic on many
/// Android devices) use pre-rendered bundled clips as the PRIMARY path to
/// eliminate the silent-tap failure mode; system TTS is the free-typed-text
/// fallback. See ADR 0008.
enum TtsStrategy {
  /// Rely on the OS text-to-speech engine for this locale.
  systemOnly,

  /// Bundled pre-rendered clips for the fixed core vocabulary are primary;
  /// system TTS is the fallback for free-typed text only.
  bundledClips,

  /// Human-recorded clips (future; e.g. a clinician or family voice).
  selfRecorded,
}

/// Whether this locale's content has cleared native + clinical review.
///
/// Per ADR 0008 the review bar is an alpha-EXIT criterion, not a merge gate:
/// MT + LLM drafts ship as [provisional]. The 48 `voice_out` words were to be
/// native + BCBA reviewed and flipped to [nativeReviewed] before the public
/// release, but that gate was consciously WAIVED for GA (no review capacity or
/// means; see ADR 0008 amendment 2026-06-09): es + ar ship at GA still
/// [provisional]. Flip the affected locale(s) if/when a native + clinical pass
/// happens.
enum ReviewStatus { provisional, nativeReviewed }

/// One declarative row per supported language.
class LocaleSpec {
  const LocaleSpec({
    required this.code,
    required this.direction,
    required this.ttsStrategy,
    required this.reviewStatus,
    required this.englishName,
    required this.nativeName,
    this.requiredFontFamily,
  });

  /// ISO 639-1 language code (e.g. `en`, `ar`, `es`).
  final String code;

  /// Text direction. Drives RTL purely through [Directionality]; no code path
  /// branches on [code] for layout.
  final TextDirection direction;

  /// Audio production strategy for this locale.
  final TtsStrategy ttsStrategy;

  /// Review state of this locale's drafted content.
  final ReviewStatus reviewStatus;

  /// English name (diagnostics / logs).
  final String englishName;

  /// Endonym shown in the in-app language picker.
  final String nativeName;

  /// Font family that fully covers this script, or null when the app's
  /// default font (plus platform fallback) is sufficient.
  ///
  /// NOTE: Arabic shaping currently relies on platform font fallback. Bundling
  /// a dedicated Arabic face (e.g. a Noto / Cairo family) and setting it here
  /// is a tracked follow-up; the field exists so that becomes a data change.
  final String? requiredFontFamily;

  Locale get locale => Locale(code);

  bool get isRtl => direction == TextDirection.rtl;
}

/// The registry. Order is the display order in the language picker.
class LocaleRegistry {
  const LocaleRegistry._();

  static const List<LocaleSpec> all = <LocaleSpec>[
    LocaleSpec(
      code: 'en',
      direction: TextDirection.ltr,
      // Bundled clips primary for every launch locale (not just Arabic): a
      // consistent warm neural voice across the core vocabulary, rather than
      // whatever robotic voice each device defaults to. See ADR 0004 amendment.
      ttsStrategy: TtsStrategy.bundledClips,
      reviewStatus: ReviewStatus.nativeReviewed,
      englishName: 'English',
      nativeName: 'English',
    ),
    LocaleSpec(
      code: 'es',
      direction: TextDirection.ltr,
      ttsStrategy: TtsStrategy.bundledClips,
      reviewStatus: ReviewStatus.provisional,
      englishName: 'Spanish',
      nativeName: 'Español',
    ),
    LocaleSpec(
      code: 'ar',
      direction: TextDirection.rtl,
      // Bundled clips primary (ADR 0008): many Android devices ship no Arabic
      // system voice, so a system-only path would mean silent taps.
      ttsStrategy: TtsStrategy.bundledClips,
      reviewStatus: ReviewStatus.provisional,
      englishName: 'Arabic',
      nativeName: 'العربية',
      // Bundled Cairo (OFL) rather than the platform Arabic font, which is
      // absent or poor on many tablets. Applied in main.dart's ThemeData.
      requiredFontFamily: 'Cairo',
    ),
  ];

  /// The default / fallback locale. English is always present and reviewed.
  static const Locale fallback = Locale('en');

  static List<Locale> get supportedLocales =>
      all.map((s) => s.locale).toList(growable: false);

  static List<String> get supportedCodes =>
      all.map((s) => s.code).toList(growable: false);

  static LocaleSpec? specForCode(String code) {
    for (final s in all) {
      if (s.code == code) return s;
    }
    return null;
  }

  static LocaleSpec specForLocale(Locale locale) =>
      specForCode(locale.languageCode) ?? specForCode(fallback.languageCode)!;

  /// `MaterialApp.localeResolutionCallback`. Matches on language code only
  /// (we do not regionalize yet); anything unsupported resolves to [fallback].
  static Locale resolve(Locale? device, Iterable<Locale> supported) {
    if (device != null && specForCode(device.languageCode) != null) {
      return Locale(device.languageCode);
    }
    return fallback;
  }

  /// The locale the app is actually presenting: the explicit settings
  /// [override] when set, otherwise the device locale resolved against the
  /// supported set (same rule [MaterialApp] applies via [resolve]). Use this,
  /// not a hardcoded 'en', anywhere the effective locale drives behavior (e.g.
  /// the bandit context key's day-type / weekend calc), so a follow-system
  /// Arabic or Spanish user is modeled with their real locale.
  static Locale effectiveLocale(String? override) {
    if (override != null && override.isNotEmpty) return Locale(override);
    return resolve(PlatformDispatcher.instance.locale, supportedLocales);
  }
}
