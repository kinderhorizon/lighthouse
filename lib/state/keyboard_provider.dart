/// State management for the Smart AAC Keyboard and quick phrases.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/keyboard/smart_keyboard_service.dart';
import 'profile_provider.dart';

final smartKeyboardServiceProvider = Provider<SmartKeyboardService>((ref) {
  return SmartKeyboardService();
});

class QuickPhrasesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final activeProfile = await ref.watch(activeProfileProvider.future);
    final service = ref.watch(smartKeyboardServiceProvider);
    return service.loadQuickPhrases(activeProfile.id);
  }

  Future<void> addPhrase(String phrase) async {
    final activeProfile = await ref.read(activeProfileProvider.future);
    final service = ref.read(smartKeyboardServiceProvider);
    await service.saveQuickPhrase(activeProfile.id, phrase);
    state = AsyncData(await service.loadQuickPhrases(activeProfile.id));
  }

  Future<void> removePhrase(String phrase) async {
    final activeProfile = await ref.read(activeProfileProvider.future);
    final service = ref.read(smartKeyboardServiceProvider);
    await service.deleteQuickPhrase(activeProfile.id, phrase);
    state = AsyncData(await service.loadQuickPhrases(activeProfile.id));
  }
}

final quickPhrasesProvider =
    AsyncNotifierProvider<QuickPhrasesNotifier, List<String>>(
  QuickPhrasesNotifier.new,
);
