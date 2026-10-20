import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/cards/personal_card_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PersonalCardStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('personal_cards_test_');
    store = PersonalCardStore(baseDirOverride: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PersonalCardStore Tests', () {
    test('seeds default starter cards for empty profile', () async {
      final cards = await store.loadCards('profile_child_1');
      expect(cards, isNotEmpty);
      expect(cards.any((c) => c.name == 'Mother'), isTrue);
      expect(cards.any((c) => c.name == 'Father'), isTrue);
      expect(cards.any((c) => c.name == 'My House'), isTrue);
    });

    test('strict profile isolation: cards do not leak across profiles', () async {
      // Create custom card for Child 1
      final cardChild1 = PersonalCard(
        id: 'c1',
        profileId: 'child_1',
        name: 'Teddy Bear',
        category: PersonalCardCategory.things,
        imageUri: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await store.saveCard(cardChild1);

      // Create custom card for Child 2
      final cardChild2 = PersonalCard(
        id: 'c2',
        profileId: 'child_2',
        name: 'Robot',
        category: PersonalCardCategory.things,
        imageUri: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await store.saveCard(cardChild2);

      final child1Cards = await store.loadCards('child_1');
      final child2Cards = await store.loadCards('child_2');

      expect(child1Cards.any((c) => c.name == 'Teddy Bear'), isTrue);
      expect(child1Cards.any((c) => c.name == 'Robot'), isFalse);

      expect(child2Cards.any((c) => c.name == 'Robot'), isTrue);
      expect(child2Cards.any((c) => c.name == 'Teddy Bear'), isFalse);
    });

    test('adds, updates, and deletes personal cards', () async {
      final now = DateTime.now();
      final card = PersonalCard(
        id: 'card_apple',
        profileId: 'user_x',
        name: 'Red Apple',
        category: PersonalCardCategory.food,
        imageUri: '/photo/apple.jpg',
        createdAt: now,
        updatedAt: now,
      );

      await store.saveCard(card);
      var cards = await store.loadCards('user_x');
      expect(cards.any((c) => c.id == 'card_apple'), isTrue);

      // Update card
      final updated = card.copyWith(name: 'Sweet Red Apple');
      await store.saveCard(updated);
      cards = await store.loadCards('user_x');
      final found = cards.firstWhere((c) => c.id == 'card_apple');
      expect(found.name, equals('Sweet Red Apple'));

      // Delete card
      final deleted = await store.deleteCard('user_x', 'card_apple');
      expect(deleted, isTrue);
      cards = await store.loadCards('user_x');
      expect(cards.any((c) => c.id == 'card_apple'), isFalse);
    });
  });
}
