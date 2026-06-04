/// Test helper: a MaterialApp configured with the app's localization
/// delegates, so any widget under test that calls AppLocalizations.of(context)
/// resolves. Use this instead of a bare `MaterialApp(home: ...)` whenever the
/// widget tree reads localized strings.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lighthouse/l10n/app_localizations.dart';

/// Wrapped in a [ProviderScope] because production always runs under one, and
/// widgets like [MathGate] and the first-use-tip hosts now read providers.
/// Tests needing provider overrides should build their own ProviderScope.
Widget localizedApp(Widget home, {Locale? locale}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}
