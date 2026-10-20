/// State management for personal custom AAC cards and personal boards.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/cards/personal_card_store.dart';
import 'profile_provider.dart';

final personalCardStoreProvider = Provider<PersonalCardStore>((ref) {
  return PersonalCardStore();
});

class PersonalCardsNotifier extends AsyncNotifier<List<PersonalCard>> {
  @override
  Future<List<PersonalCard>> build() async {
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;
    final profileId = activeProfile?.id ?? 'default';
    final store = ref.watch(personalCardStoreProvider);
    return store.loadCards(profileId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  Future<void> saveCard(PersonalCard card) async {
    final store = ref.read(personalCardStoreProvider);
    await store.saveCard(card);
    ref.invalidateSelf();
  }

  Future<void> deleteCard(String cardId) async {
    final activeProfile = ref.read(activeProfileProvider).valueOrNull;
    final profileId = activeProfile?.id ?? 'default';
    final store = ref.read(personalCardStoreProvider);
    await store.deleteCard(profileId, cardId);
    ref.invalidateSelf();
  }

  Future<void> toggleFavorite(String cardId) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((c) => c.id == cardId);
    if (idx >= 0) {
      final card = current[idx];
      final updated = card.copyWith(isFavorite: !card.isFavorite);
      await saveCard(updated);
    }
  }
}

final personalCardsProvider =
    AsyncNotifierProvider<PersonalCardsNotifier, List<PersonalCard>>(
  PersonalCardsNotifier.new,
);

/// Returns all personal cards assigned to [boardId] for the active profile.
final personalCardsForBoardProvider =
    Provider.family<List<PersonalCard>, String>((ref, boardId) {
  final all = ref.watch(personalCardsProvider).valueOrNull ?? const [];
  final matches = all.where((c) => c.boardIds.contains(boardId)).toList()
    ..sort((a, b) {
      final ord = a.sortOrder.compareTo(b.sortOrder);
      if (ord != 0) return ord;
      return a.createdAt.compareTo(b.createdAt);
    });
  return matches;
});

/// Returns favorite personal cards for active profile.
final favoritePersonalCardsProvider = Provider<List<PersonalCard>>((ref) {
  final all = ref.watch(personalCardsProvider).valueOrNull ?? const [];
  return all.where((c) => c.isFavorite).toList();
});

/// Generates an [AACBoard] for a personal board ID.
///
/// Ensures stable motor planning positions: cards are placed at fixed row, col
/// coordinates in a deterministic grid, and a trailing "+ Add Card" tile is placed.
AACBoard generatePersonalBoard({
  required String boardId,
  required List<PersonalCard> cards,
  int columns = 4,
}) {
  final localizedNames = switch (boardId) {
    PersonalBoardId.myFamily => {
        'en': 'My Family',
        'ar': 'عائلتي',
        'ar_dz': 'دارنا',
        'de': 'Meine Familie',
      },
    PersonalBoardId.myFriends => {
        'en': 'My Friends',
        'ar': 'أصدقائي',
        'ar_dz': 'صحابي',
        'de': 'Meine Freunde',
      },
    PersonalBoardId.myThings => {
        'en': 'My Things',
        'ar': 'أشيائي',
        'ar_dz': 'دوزاني',
        'de': 'Meine Sachen',
      },
    PersonalBoardId.myFavoriteFood => {
        'en': 'My Favorite Food',
        'ar': 'طعامي المفضل',
        'ar_dz': 'ماكلتي المفضلة',
        'de': 'Mein Lieblingsessen',
      },
    PersonalBoardId.myPlaces => {
        'en': 'My Places',
        'ar': 'أماكني المفضلة',
        'ar_dz': 'بلايصي',
        'de': 'Meine Orte',
      },
    PersonalBoardId.myActivities => {
        'en': 'My Activities',
        'ar': 'نشاطاتي',
        'ar_dz': 'نشاطاتي',
        'de': 'Meine Aktivitäten',
      },
    _ => {
        'en': 'Personal Board',
        'ar': 'لوحة مخصصة',
        'ar_dz': 'طابلو خاص',
        'de': 'Eigene Tafel',
      },
  };

  final defaultName = localizedNames['en']!;

  final buttons = <AACButton>[];

  // 1. Map cards into buttons at stable slots
  for (int i = 0; i < cards.length; i++) {
    final row = i ~/ columns;
    final col = i % columns;
    final card = cards[i];
    buttons.add(card.toAacButton(position: (row: row, col: col)));
  }

  // 2. Trailing "+ Add Card" special tile
  final addCardIndex = cards.length;
  final addRow = addCardIndex ~/ columns;
  final addCol = addCardIndex % columns;

  buttons.add(
    AACButton(
      id: 'btn_add_card_$boardId',
      label: '+ Add Card',
      labelByLocale: const {
        'en': '+ Add Card',
        'ar': '+ إضافة بطاقة',
        'ar_dz': '+ زيد بطاقة',
        'de': '+ Karte hinzufügen',
      },
      type: AACButtonType.phrase,
      position: (row: addRow, col: addCol),
      category: 'action_add',
      baseWeight: 0.1,
      iconUri: 'symbol://add_circle',
      voiceOut: '',
      voiceOutByLocale: const {},
    ),
  );

  final totalRows = ((addCardIndex + 1) / columns).ceil().clamp(3, 8);

  return AACBoard(
    schemaVersion: '1.3',
    boardId: boardId,
    boardName: defaultName,
    boardNameByLocale: localizedNames,
    gridDimensions: (rows: totalRows, cols: columns),
    colorKey: const {
      'family': '#FFFFA6',
      'friends': '#FFFFA6',
      'caregivers': '#FFFFA6',
      'things': '#FFD9A6',
      'food': '#FFD9A6',
      'activities': '#C2FFC2',
      'places': '#FFD9A6',
      'feelings': '#A6D9FF',
      'actions': '#C2FFC2',
      'custom': '#FFF2DF',
      'action_add': '#FAF4EA',
    },
    buttons: buttons,
  );
}
