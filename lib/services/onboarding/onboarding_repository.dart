/// Onboarding persistence.
///
/// Persists the small amount of state ADR 0003 needs: whether the parent
/// has completed the first-launch flow, and the optional Q2 context-label
/// answer ("Home" / "School" / "Both" / "Other"). Uses SharedPreferences
/// because the data is small key-value, not high-frequency event log
/// (Isar's job).
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Persistable answer to onboarding Q2. Lighthouse stores the parent's
/// label for the FIRST WiFi SSID hash seen at home; the bandit operates
/// on the hash regardless.
enum OnboardingHomeLabel {
  home,
  school,
  both,
  other;

  String toJson() => name;

  static OnboardingHomeLabel? tryParse(String? value) {
    if (value == null) return null;
    for (final v in OnboardingHomeLabel.values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

class OnboardingState {
  const OnboardingState({
    required this.completed,
    required this.homeLabel,
  });

  final bool completed;
  final OnboardingHomeLabel? homeLabel;

  OnboardingState copyWith({
    bool? completed,
    OnboardingHomeLabel? homeLabel,
    bool clearHomeLabel = false,
  }) {
    return OnboardingState(
      completed: completed ?? this.completed,
      homeLabel: clearHomeLabel ? null : (homeLabel ?? this.homeLabel),
    );
  }

  static const initial =
      OnboardingState(completed: false, homeLabel: null);
}

class OnboardingRepository {
  OnboardingRepository({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const _keyCompleted = 'onboarding.completed';
  static const _keyHomeLabel = 'onboarding.home_label';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _cached;

  Future<SharedPreferences> _prefs() async {
    if (_cached != null) return _cached!;
    _cached = _prefsOverride ?? await SharedPreferences.getInstance();
    return _cached!;
  }

  Future<OnboardingState> read() async {
    final p = await _prefs();
    return OnboardingState(
      completed: p.getBool(_keyCompleted) ?? false,
      homeLabel: OnboardingHomeLabel.tryParse(p.getString(_keyHomeLabel)),
    );
  }

  Future<void> setHomeLabel(OnboardingHomeLabel? label) async {
    final p = await _prefs();
    if (label == null) {
      await p.remove(_keyHomeLabel);
    } else {
      await p.setString(_keyHomeLabel, label.toJson());
    }
  }

  Future<void> markComplete() async {
    final p = await _prefs();
    await p.setBool(_keyCompleted, true);
  }

  /// Used by "Re-run onboarding" in Settings (Phase 1 Settings work, next
  /// session). Wipes both keys.
  Future<void> reset() async {
    final p = await _prefs();
    await p.remove(_keyCompleted);
    await p.remove(_keyHomeLabel);
  }
}
