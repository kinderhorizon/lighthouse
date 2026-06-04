/// Temporal context resolution.
///
/// PRD section 3.1 defines five time blocks (Morning, School,
/// Afternoon, Dinner, Night) and a Weekday/Weekend day type. The
/// weekend is locale-aware: in some Middle East locales (and Hebrew
/// Israel) the weekend is Fri/Sat rather than Sat/Sun.
///
/// All functions here are pure and side-effect-free; the caller
/// supplies the [DateTime] and [Locale] so this code is trivially
/// testable against frozen times.
library;

import 'dart:ui';

enum TimeBlock {
  morning,
  school,
  afternoon,
  dinner,
  night;

  String get key => switch (this) {
        TimeBlock.morning => 'Morning',
        TimeBlock.school => 'School',
        TimeBlock.afternoon => 'Afternoon',
        TimeBlock.dinner => 'Dinner',
        TimeBlock.night => 'Night',
      };
}

enum DayType {
  weekday,
  weekend;

  String get key => switch (this) {
        DayType.weekday => 'Weekday',
        DayType.weekend => 'Weekend',
      };
}

/// Returns the [TimeBlock] that contains the hour of [at].
///
/// Boundaries are inclusive on the lower end and exclusive on the
/// upper end (Morning is [6, 9), School is [9, 14), etc.) so the
/// transition is deterministic.
TimeBlock timeBlockFor(DateTime at) {
  final hour = at.hour;
  if (hour >= 6 && hour < 9) return TimeBlock.morning;
  if (hour >= 9 && hour < 14) return TimeBlock.school;
  if (hour >= 14 && hour < 17) return TimeBlock.afternoon;
  if (hour >= 17 && hour < 20) return TimeBlock.dinner;
  return TimeBlock.night;
}

/// Returns Weekend if [at] falls on the locale's weekend, Weekday
/// otherwise. Falls back to Sat/Sun for any locale not in the
/// explicit Fri/Sat list. The ContextManager passes the active
/// device locale; settings.localeOverride is the source of truth.
DayType dayTypeFor(DateTime at, Locale locale) {
  // Dart DateTime.weekday: Mon=1 ... Sun=7. Fri=5, Sat=6, Sun=7.
  final wd = at.weekday;
  if (_isFriSatWeekendLocale(locale)) {
    return (wd == DateTime.friday || wd == DateTime.saturday)
        ? DayType.weekend
        : DayType.weekday;
  }
  return (wd == DateTime.saturday || wd == DateTime.sunday)
      ? DayType.weekend
      : DayType.weekday;
}

/// Locales whose weekend is Friday + Saturday. The list is the
/// intersection of (a) common Middle East / North Africa Arabic
/// locales and (b) locales we actually ship Tier 1 / Tier 2 board
/// translations for. Other countries observe Fri/Sat too (e.g., AE,
/// KW, OM, QA, BH); they are matched via country code as we ship
/// more localized boards.
bool _isFriSatWeekendLocale(Locale locale) {
  final lang = locale.languageCode.toLowerCase();
  final country = locale.countryCode?.toUpperCase();
  if (lang == 'ar') {
    // All Arabic locales we currently support follow Fri/Sat.
    return true;
  }
  if (lang == 'he') return true; // Hebrew (Israel)
  if (lang == 'fa') return true; // Persian / Farsi (Iran, Afghanistan)
  if (country == 'IL' || country == 'IR' || country == 'AF') return true;
  return false;
}
