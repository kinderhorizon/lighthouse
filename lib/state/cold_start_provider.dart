/// Loads the active locale's context-aware cold-start artifact (ADR 0003,
/// `tools/cold_start_prior/`). One shared instance read by BOTH the bandit
/// ranker and the bandit updater, so they resolve a no-row button's prior from
/// the same data and can never diverge.
///
/// Manual Riverpod (no build_runner), like [contentOverlayStoreProvider]. Lives
/// in its own file because both `glow_provider.dart` (ranker) and
/// `context_provider.dart` (updater) depend on it, and `glow_provider` already
/// imports `context_provider`; a shared third file avoids the import cycle.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/locale_registry.dart';
import '../logic/logic.dart';
import 'settings_provider.dart';

/// Loads `assets/cold_start/<locale>.json` for the active (override-aware)
/// locale once and parses it to a [ContextualColdStart]. keepAlive (a plain
/// `FutureProvider` is not auto-disposed) so the ~750KB artifact is parsed once
/// per locale, not per rank.
///
/// FAIL-SAFE: a missing/unsupported-locale asset or any parse error yields the
/// empty resolver, so every lookup falls back to `base_weight`, i.e. exactly
/// today's context-blind behaviour. It never throws and never blocks ranking
/// (callers use `.valueOrNull ?? const ContextualColdStart.empty()`, so they
/// run with base_weight until the artifact finishes loading).
final contextualColdStartProvider =
    FutureProvider<ContextualColdStart>((ref) async {
  final settings = ref.watch(settingsNotifierProvider).valueOrNull;
  final locale = LocaleRegistry.effectiveLocale(settings?.localeOverride);
  try {
    final raw =
        await rootBundle.loadString('assets/cold_start/${locale.languageCode}.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ContextualColdStart.fromArtifactJson(json);
  } catch (_) {
    // Unsupported locale (no bundled artifact) or a malformed asset: degrade to
    // base_weight rather than failing. The child's board must never break.
    return const ContextualColdStart.empty();
  }
});
