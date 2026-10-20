import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/profile/profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ProfileStore initializes with a default profile if none exists', () async {
    final store = ProfileStore();
    final profiles = await store.listProfiles();
    expect(profiles, isNotEmpty);
    expect(profiles.first.id, 'default');
    expect(profiles.first.name, 'Default User');

    final active = await store.getActiveProfile();
    expect(active.id, 'default');
  });

  test('ProfileStore creates, switches, and persists multiple profiles', () async {
    final store = ProfileStore();
    final prof1 = await store.createProfile(name: 'Maya', voiceRate: 0.9);
    expect(prof1.name, 'Maya');
    final prof2 = await store.createProfile(
      name: 'Karim',
      interfaceLocale: 'ar',
      speechLocale: 'ar-DZ',
      highContrast: true,
    );


    final list = await store.listProfiles();
    expect(list.length, 3); // default + Maya + Karim

    await store.setActiveProfileId(prof2.id);
    final active = await store.getActiveProfile();
    expect(active.id, prof2.id);
    expect(active.name, 'Karim');
    expect(active.interfaceLocale, 'ar');
    expect(active.speechLocale, 'ar-DZ');
    expect(active.highContrast, isTrue);
  });

  test('ProfileStore prevents deleting the last remaining profile', () async {
    final store = ProfileStore();
    final profiles = await store.listProfiles();
    expect(profiles.length, 1);

    final deleted = await store.deleteProfile(profiles.first.id);
    expect(deleted, isFalse);

    // Add another profile and delete the first
    final p2 = await store.createProfile(name: 'Leo');
    final deletedSecond = await store.deleteProfile(profiles.first.id);
    expect(deletedSecond, isTrue);

    final remaining = await store.listProfiles();
    expect(remaining.length, 1);
    expect(remaining.first.id, p2.id);
  });
}
