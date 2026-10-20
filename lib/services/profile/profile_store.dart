/// Profile persistence store.
///
/// Manages multi-user profiles in [SharedPreferences], persisting isolated
/// configuration sets for speech, access method, visual preferences, and vocabulary.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';

class ProfileStore {
  ProfileStore({SharedPreferences? prefs}) : _prefsOverride = prefs;

  static const _keyProfiles = 'user_profiles_v1';
  static const _keyActiveProfileId = 'active_user_profile_id_v1';

  final SharedPreferences? _prefsOverride;
  SharedPreferences? _cached;

  Future<SharedPreferences> _prefs() async {
    if (_cached != null) return _cached!;
    _cached = _prefsOverride ?? await SharedPreferences.getInstance();
    return _cached!;
  }

  /// Lists all stored profiles. If none exist, seeds and returns a default profile.
  Future<List<UserProfile>> listProfiles() async {
    final p = await _prefs();
    final raw = p.getString(_keyProfiles);
    if (raw == null || raw.trim().isEmpty) {
      final defaultProfile = UserProfile.createDefault();
      await saveProfile(defaultProfile);
      await setActiveProfileId(defaultProfile.id);
      return <UserProfile>[defaultProfile];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .whereType<Map<String, dynamic>>()
          .map(UserProfile.fromJson)
          .toList();
      if (list.isEmpty) {
        final defaultProfile = UserProfile.createDefault();
        await saveProfile(defaultProfile);
        await setActiveProfileId(defaultProfile.id);
        return <UserProfile>[defaultProfile];
      }
      return list;
    } catch (_) {
      final defaultProfile = UserProfile.createDefault();
      await saveProfile(defaultProfile);
      await setActiveProfileId(defaultProfile.id);
      return <UserProfile>[defaultProfile];
    }
  }

  /// Returns the currently active profile.
  Future<UserProfile> getActiveProfile() async {
    final profiles = await listProfiles();
    final p = await _prefs();
    final activeId = p.getString(_keyActiveProfileId);
    if (activeId != null) {
      final match = profiles.where((prof) => prof.id == activeId);
      if (match.isNotEmpty) {
        return match.first;
      }
    }
    final first = profiles.first;
    await setActiveProfileId(first.id);
    return first;
  }

  /// Sets the active profile ID.
  Future<void> setActiveProfileId(String profileId) async {
    final p = await _prefs();
    await p.setString(_keyActiveProfileId, profileId);
  }

  /// Saves or updates a profile in storage.
  Future<void> saveProfile(UserProfile profile) async {
    final p = await _prefs();
    final raw = p.getString(_keyProfiles);
    List<UserProfile> list = <UserProfile>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        list = decoded
            .whereType<Map<String, dynamic>>()
            .map(UserProfile.fromJson)
            .toList();
      } catch (_) {
        list = <UserProfile>[];
      }
    }

    final index = list.indexWhere((it) => it.id == profile.id);
    final updated = profile.copyWith(updatedAt: DateTime.now());
    if (index >= 0) {
      list[index] = updated;
    } else {
      list.add(updated);
    }

    final encoded = jsonEncode(list.map((it) => it.toJson()).toList());
    await p.setString(_keyProfiles, encoded);
  }

  static int _idCounter = 0;

  /// Creates a new profile with a generated unique ID.
  Future<UserProfile> createProfile({
    required String name,
    String? interfaceLocale,
    String? speechLocale,
    double voiceRate = 1.0,
    double voicePitch = 1.0,
    bool highContrast = false,
  }) async {
    await listProfiles();
    final now = DateTime.now();
    final id = 'prof_${now.microsecondsSinceEpoch}_${_idCounter++}';
    final profile = UserProfile(
      id: id,
      name: name,
      interfaceLocale: interfaceLocale,
      speechLocale: speechLocale,
      voiceRate: voiceRate,
      voicePitch: voicePitch,
      highContrast: highContrast,
      createdAt: now,
      updatedAt: now,
    );
    await saveProfile(profile);
    return profile;
  }

  /// Deletes a profile by ID unless it is the only remaining profile.
  Future<bool> deleteProfile(String profileId) async {
    final profiles = await listProfiles();
    if (profiles.length <= 1) {
      // Invariant: Cannot delete the last remaining profile.
      return false;
    }

    final updated = profiles.where((it) => it.id != profileId).toList();
    final p = await _prefs();
    final encoded = jsonEncode(updated.map((it) => it.toJson()).toList());
    await p.setString(_keyProfiles, encoded);

    final activeId = p.getString(_keyActiveProfileId);
    if (activeId == profileId) {
      await setActiveProfileId(updated.first.id);
    }
    return true;
  }
}
