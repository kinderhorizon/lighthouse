/// Smart Multilingual AAC Keyboard and Word Prediction Engine.
///
/// Features:
/// - Offline prefix matching and autocomplete
/// - Integration with Personal Cards (highest priority)
/// - Multilingual core AAC dictionaries (English, German, Arabic, Algerian Darija)
/// - Next-word contextual suggestions
/// - Quick phrase management
/// - 100% offline, privacy-preserving execution
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';

class KeyboardSuggestion {
  const KeyboardSuggestion({
    required this.text,
    this.spokenText,
    this.isPersonalCard = false,
    this.isQuickPhrase = false,
    this.card,
    this.iconUri,
    this.category,
  });

  final String text;
  final String? spokenText;
  final bool isPersonalCard;
  final bool isQuickPhrase;
  final PersonalCard? card;
  final String? iconUri;
  final String? category;
}

class SmartKeyboardService {
  SmartKeyboardService({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  /// In-memory cache of quick phrases by profile ID.
  final Map<String, List<String>> _quickPhrasesCache = {};

  // Core offline dictionaries for high-frequency AAC words
  static const List<String> _enDictionary = [
    'i', 'want', 'need', 'like', 'help', 'please', 'thank you', 'yes', 'no',
    'water', 'food', 'eat', 'drink', 'more', 'all done', 'go', 'stop', 'play',
    'bathroom', 'home', 'school', 'happy', 'sad', 'tired', 'hungry', 'thirsty',
    'mom', 'dad', 'friend', 'teacher', 'book', 'toy', 'ball', 'music', 'sleep',
    'look', 'listen', 'good', 'bad', 'big', 'small', 'come', 'give', 'take',
    'where', 'what', 'who', 'when', 'why', 'how', 'me', 'you', 'we', 'they',
    'am', 'is', 'are', 'have', 'can', 'will', 'today', 'now', 'later',
  ];

  static const List<String> _deDictionary = [
    'ich', 'möchte', 'brauche', 'mag', 'hilfe', 'bitte', 'danke', 'ja', 'nein',
    'wasser', 'essen', 'trinken', 'mehr', 'fertig', 'gehen', 'stopp', 'spielen',
    'toilette', 'nach hause', 'schule', 'glücklich', 'traurig', 'müde', 'hunger', 'durst',
    'mama', 'papa', 'freund', 'lehrer', 'buch', 'spielzeug', 'ball', 'musik', 'schlafen',
    'sehen', 'hören', 'gut', 'schlecht', 'groß', 'klein', 'kommen', 'geben', 'nehmen',
    'wo', 'was', 'wer', 'wann', 'warum', 'wie', 'mich', 'dich', 'wir', 'sie',
    'bin', 'ist', 'sind', 'habe', 'kann', 'heute', 'jetzt', 'später',
  ];

  static const List<String> _arDictionary = [
    'أنا', 'أريد', 'أحتاج', 'أحب', 'مساعدة', 'من فضلك', 'شكرًا', 'نعم', 'لا',
    'ماء', 'طعام', 'أكل', 'أشرب', 'المزيد', 'انتهيت', 'أذهب', 'توقف', 'ألعب',
    'حمام', 'البيت', 'المدرسة', 'سعيد', 'حزين', 'تعبان', 'جائع', 'عطشان',
    'أمي', 'أبي', 'صديقي', 'معلمي', 'كتاب', 'لعبة', 'كرة', 'موسيقى', 'نوم',
    'أنظر', 'أسمع', 'جيد', 'سيء', 'كبير', 'صغير', 'تعال', 'أعطني', 'خذ',
    'أين', 'ماذا', 'من', 'متى', 'لماذا', 'كيف', 'نحن', 'هو', 'هي',
    'اليوم', 'الآن', 'لاحقًا',
  ];

  static const List<String> _arDzDictionary = [
    'أنا', 'راني', 'حاب', 'حابة', 'باغي', 'نسحق', 'عاوني', 'عيشك', 'يعطيك الصحة', 'إيه', 'لا',
    'الماء', 'ماكلة', 'ناكل', 'نشرب', 'زيد', 'خلاص', 'نروح', 'حبس', 'نلعب',
    'بيت الما', 'الدار', 'المسيد', 'فرحان', 'زعفان', 'عيان', 'جيعان', 'عطشان',
    'يما', 'بابا', 'صاحبي', 'الشيخ', 'كتّاب', 'لعبة', 'بالون', 'غنا', 'نرقد',
    'شوف', 'اسمع', 'مليح', 'ماشي مليح', 'كبير', 'صغير', 'أرواح', 'مدلي', 'هاك',
    'وين', 'واش', 'شكون', 'وقتاش', 'علاش', 'كيفاش', 'حنا', 'هو', 'هي',
    'اليوم', 'درك', 'من بعد', 'بزاف', 'شوية',
  ];

  /// Contextual next-word bigram predictions for key starters.
  static const Map<String, List<String>> _nextWordTransitions = {
    'i': ['want', 'need', 'like', 'feel', 'am', 'have', 'go'],
    'want': ['to', 'water', 'food', 'more', 'help', 'play', 'to go'],
    'need': ['help', 'water', 'bathroom', 'break', 'to go'],
    'ich': ['möchte', 'brauche', 'habe', 'bin', 'will'],
    'möchte': ['wasser', 'essen', 'trinken', 'spielen', 'gehen'],
    'أنا': ['أريد', 'أحتاج', 'أحب', 'سعيد', 'جائع', 'عطشان', 'تعبان'],
    'أريد': ['أن أشرب', 'أن آكل', 'الماء', 'مساعدة', 'الذهاب', 'أن ألعب'],
    'راني': ['فرحان', 'جيعان', 'عطشان', 'عيان', 'زعفان', 'حاب'],
    'حاب': ['نشرب', 'ناكل', 'نروح', 'نلعب', 'نرقد', 'الماء'],
  };

  /// Returns words starting with [prefix] in [languageCode], prioritizing:
  /// 1. Matching Personal Cards
  /// 2. Matching Quick Phrases
  /// 3. Matching Core AAC dictionary words
  List<KeyboardSuggestion> getSuggestions({
    required String prefix,
    required String languageCode,
    List<PersonalCard> personalCards = const [],
    List<String> quickPhrases = const [],
    int limit = 6,
  }) {
    final clean = prefix.trim().toLowerCase();
    final results = <KeyboardSuggestion>[];
    final seen = <String>{};

    // 1. Personal Cards prefix match
    for (final card in personalCards) {
      final cardLabel = card.labelFor(languageCode).toLowerCase();
      if (clean.isEmpty || cardLabel.startsWith(clean)) {
        if (seen.add(card.name.toLowerCase())) {
          results.add(
            KeyboardSuggestion(
              text: card.labelFor(languageCode),
              spokenText: card.speechFor(languageCode),
              isPersonalCard: true,
              card: card,
              iconUri: card.imageUri,
              category: card.category,
            ),
          );
        }
      }
      if (results.length >= limit) return results;
    }

    // 2. Quick Phrases match
    for (final phrase in quickPhrases) {
      if (clean.isEmpty || phrase.toLowerCase().startsWith(clean)) {
        if (seen.add(phrase.toLowerCase())) {
          results.add(
            KeyboardSuggestion(
              text: phrase,
              spokenText: phrase,
              isQuickPhrase: true,
            ),
          );
        }
      }
      if (results.length >= limit) return results;
    }

    // 3. Core Dictionary prefix match
    final dict = _getDictionaryFor(languageCode);
    for (final word in dict) {
      if (clean.isEmpty || word.toLowerCase().startsWith(clean)) {
        if (seen.add(word.toLowerCase())) {
          results.add(KeyboardSuggestion(text: word));
        }
      }
      if (results.length >= limit) break;
    }

    return results;
  }

  /// Predicts candidate next words after [precedingWord] in [languageCode].
  List<KeyboardSuggestion> predictNextWords({
    required String precedingWord,
    required String languageCode,
    List<PersonalCard> personalCards = const [],
    int limit = 5,
  }) {
    final clean = precedingWord.trim().toLowerCase();
    final results = <KeyboardSuggestion>[];
    final seen = <String>{};

    final transitionCandidates = _nextWordTransitions[clean] ?? const [];
    for (final next in transitionCandidates) {
      if (seen.add(next.toLowerCase())) {
        results.add(KeyboardSuggestion(text: next));
      }
    }

    if (results.length < limit) {
      // Fill with relevant personal cards if suitable
      for (final card in personalCards) {
        if (seen.add(card.name.toLowerCase())) {
          results.add(
            KeyboardSuggestion(
              text: card.labelFor(languageCode),
              spokenText: card.speechFor(languageCode),
              isPersonalCard: true,
              card: card,
              iconUri: card.imageUri,
              category: card.category,
            ),
          );
        }
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  List<String> _getDictionaryFor(String langCode) {
    final clean = langCode.replaceAll('-', '_').toLowerCase();
    if (clean.contains('dz') || clean == 'ar_dz') {
      return _arDzDictionary;
    } else if (clean.startsWith('ar')) {
      return _arDictionary;
    } else if (clean.startsWith('de')) {
      return _deDictionary;
    } else {
      return _enDictionary;
    }
  }

  /// Loads saved quick phrases for [profileId].
  Future<List<String>> loadQuickPhrases(String profileId) async {
    if (_quickPhrasesCache.containsKey(profileId)) {
      return _quickPhrasesCache[profileId]!;
    }

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final key = 'quick_phrases_$profileId';
    final saved = prefs.getStringList(key);
    if (saved != null) {
      _quickPhrasesCache[profileId] = saved;
      return saved;
    }

    // Default starter quick phrases
    final defaults = [
      'I need help please.',
      'Thank you very much.',
      'I want to drink water.',
      'I need to use the bathroom.',
    ];
    _quickPhrasesCache[profileId] = defaults;
    return defaults;
  }

  /// Saves a new quick phrase for [profileId].
  Future<void> saveQuickPhrase(String profileId, String phrase) async {
    final clean = phrase.trim();
    if (clean.isEmpty) return;

    final list = await loadQuickPhrases(profileId);
    if (!list.contains(clean)) {
      final updated = [clean, ...list];
      _quickPhrasesCache[profileId] = updated;

      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setStringList('quick_phrases_$profileId', updated);
    }
  }

  /// Deletes a quick phrase for [profileId].
  Future<void> deleteQuickPhrase(String profileId, String phrase) async {
    final list = await loadQuickPhrases(profileId);
    final updated = list.where((p) => p != phrase).toList();
    _quickPhrasesCache[profileId] = updated;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setStringList('quick_phrases_$profileId', updated);
  }
}
