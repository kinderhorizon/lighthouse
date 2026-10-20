import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/keyboard/smart_keyboard_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmartKeyboardService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = SmartKeyboardService();
  });

  group('SmartKeyboardService Tests', () {
    test('English prefix matching returns matching core words', () {
      final suggestions = service.getSuggestions(
        prefix: 'wa',
        languageCode: 'en',
      );

      final texts = suggestions.map((s) => s.text).toList();
      expect(texts, contains('want'));
      expect(texts, contains('water'));
    });

    test('German prefix matching returns German words', () {
      final suggestions = service.getSuggestions(
        prefix: 'wa',
        languageCode: 'de',
      );

      final texts = suggestions.map((s) => s.text).toList();
      expect(texts, contains('wasser'));
    });

    test('Arabic prefix matching returns Arabic words', () {
      final suggestions = service.getSuggestions(
        prefix: 'م',
        languageCode: 'ar',
      );

      final texts = suggestions.map((s) => s.text).toList();
      expect(texts, contains('ماء'));
      expect(texts, contains('مساعدة'));
    });

    test('Algerian Darija prefix matching returns Darija words', () {
      final suggestions = service.getSuggestions(
        prefix: 'ح',
        languageCode: 'ar_dz',
      );

      final texts = suggestions.map((s) => s.text).toList();
      expect(texts, contains('حاب'));
      expect(texts, contains('حابة'));
    });

    test('Personal cards take highest priority in autocomplete suggestions', () {
      final card = PersonalCard(
        id: 'c_wali',
        profileId: 'child_1',
        name: 'Walid',
        category: PersonalCardCategory.friends,
        imageUri: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final suggestions = service.getSuggestions(
        prefix: 'wa',
        languageCode: 'en',
        personalCards: [card],
      );

      expect(suggestions.first.text, equals('Walid'));
      expect(suggestions.first.isPersonalCard, isTrue);
      expect(suggestions.first.category, equals(PersonalCardCategory.friends));
    });

    test('Next-word prediction returns contextually likely candidates', () {
      final enNext = service.predictNextWords(
        precedingWord: 'want',
        languageCode: 'en',
      );
      final enTexts = enNext.map((s) => s.text).toList();
      expect(enTexts, contains('water'));
      expect(enTexts, contains('food'));

      final arNext = service.predictNextWords(
        precedingWord: 'راني',
        languageCode: 'ar_dz',
      );
      final arTexts = arNext.map((s) => s.text).toList();
      expect(arTexts, contains('فرحان'));
      expect(arTexts, contains('جيعان'));
    });

    test('Quick phrases can be saved, loaded, and matched', () async {
      await service.saveQuickPhrase('p1', 'I am thirsty.');
      final loaded = await service.loadQuickPhrases('p1');
      expect(loaded, contains('I am thirsty.'));

      final suggestions = service.getSuggestions(
        prefix: 'i am',
        languageCode: 'en',
        quickPhrases: loaded,
      );
      expect(suggestions.any((s) => s.text == 'I am thirsty.'), isTrue);
    });
  });
}
