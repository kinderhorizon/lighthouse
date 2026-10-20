/// Persistent storage for custom personal AAC cards.
///
/// Features strict profile isolation: each user profile has its own
/// card repository and local photo directory.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';
import '../util/atomic_file.dart';

class PersonalCardStore {
  PersonalCardStore({Directory? baseDirOverride})
      : _baseDirOverride = baseDirOverride;

  final Directory? _baseDirOverride;

  /// Maximum allowed byte size for imported or attached photos (5 MB).
  static const int maxImageByteSize = 5 * 1024 * 1024;

  /// In-memory cache keyed by profile ID.
  final Map<String, List<PersonalCard>> _memCache = {};

  Future<Directory> _profileDirectory(String profileId) async {
    if (_baseDirOverride != null) {
      final dir = Directory('${_baseDirOverride.path}/profiles/$profileId');
      if (!dir.existsSync()) await dir.create(recursive: true);
      return dir;
    }

    if (kIsWeb) {
      // On web, no direct filesystem; fallback to in-memory handling
      return Directory('/web_dummy');
    }

    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/profiles/$profileId');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Default starter cards seeded for a profile to make personal boards immediately functional.
  List<PersonalCard> _defaultStarterCards(String profileId) {
    final now = DateTime.now();
    return [
      PersonalCard(
        id: 'starter_mother_$profileId',
        profileId: profileId,
        name: 'Mother',
        speechText: 'Mother',
        category: PersonalCardCategory.family,
        imageUri: 'assets/symbols/people/mother.png',
        labelsByLocale: {
          'en': 'Mother',
          'ar': 'أمي',
          'ar_dz': 'يما',
          'de': 'Mama',
        },
        speechByLocale: {
          'en': 'Mom',
          'ar': 'أمي',
          'ar_dz': 'يما',
          'de': 'Mama',
        },
        boardIds: [PersonalBoardId.myFamily],
        isFavorite: true,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      PersonalCard(
        id: 'starter_father_$profileId',
        profileId: profileId,
        name: 'Father',
        speechText: 'Father',
        category: PersonalCardCategory.family,
        imageUri: 'assets/symbols/people/father.png',
        labelsByLocale: {
          'en': 'Father',
          'ar': 'أبي',
          'ar_dz': 'بابا',
          'de': 'Papa',
        },
        speechByLocale: {
          'en': 'Dad',
          'ar': 'أبي',
          'ar_dz': 'بابا',
          'de': 'Papa',
        },
        boardIds: [PersonalBoardId.myFamily],
        isFavorite: true,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
      PersonalCard(
        id: 'starter_home_$profileId',
        profileId: profileId,
        name: 'My House',
        speechText: 'My house',
        category: PersonalCardCategory.places,
        imageUri: 'assets/symbols/places/house.png',
        labelsByLocale: {
          'en': 'My House',
          'ar': 'بيتي',
          'ar_dz': 'دارنا',
          'de': 'Mein Zuhause',
        },
        speechByLocale: {
          'en': 'My house',
          'ar': 'بيتي',
          'ar_dz': 'دارنا',
          'de': 'Mein Zuhause',
        },
        boardIds: [PersonalBoardId.myPlaces],
        isFavorite: true,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  /// Loads all cards for [profileId].
  Future<List<PersonalCard>> loadCards(String profileId) async {
    if (kIsWeb) {
      return _memCache.putIfAbsent(profileId, () => _defaultStarterCards(profileId));
    }

    try {
      final dir = await _profileDirectory(profileId);
      final file = File('${dir.path}/personal_cards.json');

      if (!file.existsSync()) {
        final initial = _defaultStarterCards(profileId);
        await saveAllCards(profileId, initial);
        _memCache[profileId] = initial;
        return initial;
      }

      dynamic decoded;
      try {
        final raw = await file.readAsString();
        decoded = jsonDecode(raw);
      } catch (err) {
        debugPrint('PersonalCardStore: detected corrupt personal_cards.json: $err. Archiving and resetting.');
        try {
          final corruptBackup = File('${file.path}.corrupt_${DateTime.now().millisecondsSinceEpoch}');
          await file.copy(corruptBackup.path);
        } catch (_) {}
        final initial = _defaultStarterCards(profileId);
        await saveAllCards(profileId, initial);
        _memCache[profileId] = initial;
        return initial;
      }

      if (decoded is! List) {
        final initial = _defaultStarterCards(profileId);
        await saveAllCards(profileId, initial);
        _memCache[profileId] = initial;
        return initial;
      }

      final list = <PersonalCard>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            list.add(PersonalCard.fromJson(item));
          } catch (e) {
            debugPrint('PersonalCardStore: skipping corrupted card item: $e');
          }
        }
      }

      _memCache[profileId] = list;
      return list;
    } catch (e) {
      debugPrint('PersonalCardStore loadCards error: $e');
      return _memCache[profileId] ?? _defaultStarterCards(profileId);
    }
  }

  /// Saves the full list of cards for [profileId].
  Future<void> saveAllCards(String profileId, List<PersonalCard> cards) async {
    _memCache[profileId] = List.from(cards);

    if (kIsWeb) return;

    try {
      final dir = await _profileDirectory(profileId);
      if (!dir.existsSync()) await dir.create(recursive: true);
      final file = File('${dir.path}/personal_cards.json');
      if (!file.parent.existsSync()) await file.parent.create(recursive: true);
      final jsonString = jsonEncode(cards.map((c) => c.toJson()).toList());
      await writeStringAtomically(file, jsonString);
    } catch (e) {
      debugPrint('PersonalCardStore saveAllCards error: $e');
    }
  }

  /// Adds or updates a single [card].
  Future<void> saveCard(PersonalCard card) async {
    final cards = await loadCards(card.profileId);
    final idx = cards.indexWhere((c) => c.id == card.id);
    final updated = List<PersonalCard>.from(cards);
    if (idx >= 0) {
      updated[idx] = card.copyWith(updatedAt: DateTime.now());
    } else {
      updated.add(card);
    }
    await saveAllCards(card.profileId, updated);
  }

  /// Deletes a single card by [cardId] from [profileId].
  Future<bool> deleteCard(String profileId, String cardId) async {
    final cards = await loadCards(profileId);
    final beforeCount = cards.length;
    final updated = cards.where((c) => c.id != cardId).toList();
    if (updated.length != beforeCount) {
      await saveAllCards(profileId, updated);
      return true;
    }
    return false;
  }

  /// Saves image bytes to disk (mobile) or base64 (web) and returns the resulting URI.
  /// Throws [ArgumentError] if [bytes] exceeds [maxImageByteSize] (5MB).
  Future<String> saveCardImage({
    required String profileId,
    required String cardId,
    required Uint8List bytes,
    String mimeType = 'image/jpeg',
  }) async {
    if (bytes.length > maxImageByteSize) {
      throw ArgumentError(
        'Image file size (${bytes.length} bytes) exceeds the maximum allowed limit of ${maxImageByteSize} bytes (5MB).',
      );
    }

    if (kIsWeb || _baseDirOverride == null && kIsWeb) {
      final base64Data = base64Encode(bytes);
      return 'data:$mimeType;base64,$base64Data';
    }

    try {
      final dir = await _profileDirectory(profileId);
      final photoDir = Directory('${dir.path}/photos');
      if (!photoDir.existsSync()) await photoDir.create(recursive: true);

      final extension = mimeType.contains('png') ? 'png' : 'jpg';
      final file = File('${photoDir.path}/${cardId}_${DateTime.now().millisecondsSinceEpoch}.$extension');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('PersonalCardStore saveCardImage error, falling back to data URI: $e');
      final base64Data = base64Encode(bytes);
      return 'data:$mimeType;base64,$base64Data';
    }
  }
}
