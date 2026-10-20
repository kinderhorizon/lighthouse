import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';

void main() {
  group('PersonalCard Model Tests', () {
    test('serializes and deserializes correctly via JSON', () {
      final now = DateTime.now();
      final card = PersonalCard(
        id: 'card_123',
        profileId: 'child_a',
        name: 'Mama',
        speechText: 'I love you Mama',
        category: PersonalCardCategory.family,
        imageUri: '/path/to/mama.jpg',
        labelsByLocale: {
          'ar': 'أمي',
          'ar_dz': 'يما',
          'de': 'Mama',
          'en': 'Mother',
        },
        speechByLocale: {
          'ar': 'أمي الحبيبة',
          'ar_dz': 'يما لعزيزة',
          'de': 'Meine liebe Mama',
          'en': 'My sweet mother',
        },
        boardIds: [PersonalBoardId.myFamily],
        isFavorite: true,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      );

      final json = card.toJson();
      final reconstructed = PersonalCard.fromJson(json);

      expect(reconstructed.id, equals('card_123'));
      expect(reconstructed.profileId, equals('child_a'));
      expect(reconstructed.name, equals('Mama'));
      expect(reconstructed.speechText, equals('I love you Mama'));
      expect(reconstructed.category, equals(PersonalCardCategory.family));
      expect(reconstructed.imageUri, equals('/path/to/mama.jpg'));
      expect(reconstructed.labelsByLocale['ar'], equals('أمي'));
      expect(reconstructed.labelsByLocale['ar_dz'], equals('يما'));
      expect(reconstructed.labelsByLocale['de'], equals('Mama'));
      expect(reconstructed.labelsByLocale['en'], equals('Mother'));
      expect(reconstructed.speechByLocale['ar_dz'], equals('يما لعزيزة'));
      expect(reconstructed.boardIds, contains(PersonalBoardId.myFamily));
      expect(reconstructed.isFavorite, isTrue);
      expect(reconstructed.sortOrder, equals(1));
    });

    test('labelFor resolves localized strings with fallback', () {
      final card = PersonalCard(
        id: 'card_456',
        profileId: 'child_a',
        name: 'Water Bottle',
        category: PersonalCardCategory.things,
        imageUri: '',
        labelsByLocale: {
          'ar': 'قارورة ماء',
          'de': 'Wasserflasche',
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(card.labelFor('ar'), equals('قارورة ماء'));
      expect(card.labelFor('de'), equals('Wasserflasche'));
      expect(card.labelFor('en'), equals('Water Bottle')); // Fallback to name
    });

    test('converts seamlessly to AACButton with clinical weight', () {
      final card = PersonalCard(
        id: 'card_789',
        profileId: 'child_a',
        name: 'Home',
        speechText: 'I want to go home',
        category: PersonalCardCategory.places,
        imageUri: 'symbol://house',
        labelsByLocale: {'ar': 'بيتي'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final btn = card.toAacButton();
      expect(btn.id, equals('card_789'));
      expect(btn.label, equals('Home'));
      expect(btn.voiceOut, equals('I want to go home'));
      expect(btn.category, equals(PersonalCardCategory.places));
      expect(btn.type, equals(AACButtonType.word));
      expect(btn.baseWeight, equals(0.9)); // Prioritized weight
    });
  });
}
