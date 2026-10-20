/// Profile state management.
///
/// Multi-user profile management for clinical and home use.
/// Supports switching active child/communicator profiles with independent
/// speech rates, pitches, access modes, high contrast, and locales.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/profile/profile_store.dart';

final profileStoreProvider = Provider<ProfileStore>((ref) {
  return ProfileStore();
});

class ProfileListNotifier extends AsyncNotifier<List<UserProfile>> {
  @override
  Future<List<UserProfile>> build() {
    return ref.read(profileStoreProvider).listProfiles();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await ref.read(profileStoreProvider).listProfiles());
  }
}

final profileListProvider =
    AsyncNotifierProvider<ProfileListNotifier, List<UserProfile>>(
  ProfileListNotifier.new,
);

class ActiveProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() {
    return ref.read(profileStoreProvider).getActiveProfile();
  }

  Future<void> switchProfile(String profileId) async {
    final store = ref.read(profileStoreProvider);
    await store.setActiveProfileId(profileId);
    final active = await store.getActiveProfile();
    state = AsyncData(active);
    await ref.read(profileListProvider.notifier).refresh();
  }

  Future<UserProfile> createProfile({
    required String name,
    String? interfaceLocale,
    String? speechLocale,
    double voiceRate = 1.0,
    double voicePitch = 1.0,
    bool highContrast = false,
  }) async {
    final store = ref.read(profileStoreProvider);
    final profile = await store.createProfile(
      name: name,
      interfaceLocale: interfaceLocale,
      speechLocale: speechLocale,
      voiceRate: voiceRate,
      voicePitch: voicePitch,
      highContrast: highContrast,
    );
    await store.setActiveProfileId(profile.id);
    state = AsyncData(profile);
    await ref.read(profileListProvider.notifier).refresh();
    return profile;
  }

  Future<void> updateActiveProfile(UserProfile updated) async {
    final store = ref.read(profileStoreProvider);
    await store.saveProfile(updated);
    state = AsyncData(updated);
    await ref.read(profileListProvider.notifier).refresh();
  }

  Future<bool> deleteProfile(String profileId) async {
    final store = ref.read(profileStoreProvider);
    final ok = await store.deleteProfile(profileId);
    if (ok) {
      final active = await store.getActiveProfile();
      state = AsyncData(active);
      await ref.read(profileListProvider.notifier).refresh();
    }
    return ok;
  }
}

final activeProfileProvider =
    AsyncNotifierProvider<ActiveProfileNotifier, UserProfile>(
  ActiveProfileNotifier.new,
);
