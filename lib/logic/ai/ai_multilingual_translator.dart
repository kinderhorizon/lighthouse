/// Offline AI Multilingual Translator for AAC.
///
/// Provides offline translation between Arabic (ar), Algerian Darija (ar_dz),
/// German (de), and English (en) for AAC communicative phrases and vocabulary.
///
/// Guaranteed zero cloud calls, zero data leaks, and deterministic accuracy.
library;

class AIMultilingualTranslator {
  const AIMultilingualTranslator();

  static const List<Map<String, String>> _phraseCorpus = [
    {
      'en': 'I want to drink water.',
      'ar': 'أريد أن أشرب الماء.',
      'ar_dz': 'حاب نشرب الماء.',
      'de': 'Ich möchte Wasser trinken.',
    },
    {
      'en': 'I am hungry.',
      'ar': 'أنا جائع.',
      'ar_dz': 'راني جيعان.',
      'de': 'Ich habe Hunger.',
    },
    {
      'en': 'I want to eat.',
      'ar': 'أريد أن آكل.',
      'ar_dz': 'حاب ناكل.',
      'de': 'Ich möchte essen.',
    },
    {
      'en': 'Please help me.',
      'ar': 'ساعدني من فضلك.',
      'ar_dz': 'عاونّي من فضلك.',
      'de': 'Bitte hilf mir.',
    },
    {
      'en': 'I am tired.',
      'ar': 'أنا متعب.',
      'ar_dz': 'راني تعبان.',
      'de': 'Ich bin müde.',
    },
    {
      'en': 'I want to go home.',
      'ar': 'أريد الذهاب إلى المنزل.',
      'ar_dz': 'حاب نروح للدار.',
      'de': 'Ich möchte nach Hause gehen.',
    },
    {
      'en': 'What is this?',
      'ar': 'ما هذا؟',
      'ar_dz': 'واش هذا؟',
      'de': 'Was ist das?',
    },
    {
      'en': 'I feel happy.',
      'ar': 'أنا سعيد.',
      'ar_dz': 'راني فرحان.',
      'de': 'Ich bin glücklich.',
    },
    {
      'en': "I didn't understand.",
      'ar': 'لم أفهم.',
      'ar_dz': 'ما فهمتش.',
      'de': 'Ich habe es nicht verstanden.',
    },
    {
      'en': 'Thank you.',
      'ar': 'شكرًا لك.',
      'ar_dz': 'يعطيك الصحة.',
      'de': 'Vielen Dank.',
    },
    {
      'en': 'Yes.',
      'ar': 'نعم.',
      'ar_dz': 'إيه.',
      'de': 'Ja.',
    },
    {
      'en': 'No.',
      'ar': 'لا.',
      'ar_dz': 'لا لا.',
      'de': 'Nein.',
    },
    {
      'en': 'I need the bathroom.',
      'ar': 'أحتاج إلى الحمّام.',
      'ar_dz': 'حاب نروح لبيت الما.',
      'de': 'Ich muss zur Toilette.',
    },
  ];

  static const Map<String, Map<String, String>> _wordLexicon = {
    'water': {'ar': 'ماء', 'ar_dz': 'الما', 'de': 'Wasser', 'en': 'Water'},
    'ماء': {'en': 'Water', 'ar_dz': 'الما', 'de': 'Wasser', 'ar': 'ماء'},
    'الما': {'en': 'Water', 'ar': 'ماء', 'de': 'Wasser', 'ar_dz': 'الما'},
    'wasser': {'en': 'Water', 'ar': 'ماء', 'ar_dz': 'الما', 'de': 'Wasser'},
    'help': {'ar': 'مساعدة', 'ar_dz': 'عاوني', 'de': 'Hilfe', 'en': 'Help'},
    'مساعدة': {'en': 'Help', 'ar_dz': 'عاوني', 'de': 'Hilfe', 'ar': 'مساعدة'},
    'عاوني': {'en': 'Help', 'ar': 'مساعدة', 'de': 'Hilfe', 'ar_dz': 'عاوني'},
    'hilfe': {'en': 'Help', 'ar': 'مساعدة', 'ar_dz': 'عاوني', 'de': 'Hilfe'},
    'home': {'ar': 'المنزل', 'ar_dz': 'الدار', 'de': 'Zuhause', 'en': 'Home'},
    'المنزل': {'en': 'Home', 'ar_dz': 'الدار', 'de': 'Zuhause', 'ar': 'المنزل'},
    'الدار': {'en': 'Home', 'ar': 'المنزل', 'de': 'Zuhause', 'ar_dz': 'الدار'},
    'zuhause': {'en': 'Home', 'ar': 'المنزل', 'ar_dz': 'الدار', 'de': 'Zuhause'},
    'eat': {'ar': 'آكل', 'ar_dz': 'ناكل', 'de': 'essen', 'en': 'eat'},
    'آكل': {'en': 'eat', 'ar_dz': 'ناكل', 'de': 'essen', 'ar': 'آكل'},
    'ناكل': {'en': 'eat', 'ar': 'آكل', 'de': 'essen', 'ar_dz': 'ناكل'},
    'drink': {'ar': 'أشرب', 'ar_dz': 'نشرب', 'de': 'trinken', 'en': 'drink'},
    'أشرب': {'en': 'drink', 'ar_dz': 'نشرب', 'de': 'trinken', 'ar': 'أشرب'},
    'نشرب': {'en': 'drink', 'ar': 'أشرب', 'de': 'trinken', 'ar_dz': 'نشرب'},
    'happy': {'ar': 'سعيد', 'ar_dz': 'فرحان', 'de': 'glücklich', 'en': 'happy'},
    'سعيد': {'en': 'happy', 'ar_dz': 'فرحان', 'de': 'glücklich', 'ar': 'سعيد'},
    'فرحان': {'en': 'happy', 'ar': 'سعيد', 'de': 'glücklich', 'ar_dz': 'فرحان'},
    'tired': {'ar': 'متعب', 'ar_dz': 'تعبان', 'de': 'müde', 'en': 'tired'},
    'متعب': {'en': 'tired', 'ar_dz': 'تعبان', 'de': 'müde', 'ar': 'متعب'},
    'تعبان': {'en': 'tired', 'ar': 'متعب', 'de': 'müde', 'ar_dz': 'تعبان'},
    'müde': {'en': 'tired', 'ar': 'متعب', 'ar_dz': 'تعبان', 'de': 'müde'},
    'hello': {'ar': 'مرحبا', 'ar_dz': 'مرحبا', 'de': 'hallo', 'en': 'hello'},
    'hallo': {'ar': 'مرحبا', 'ar_dz': 'مرحبا', 'de': 'hallo', 'en': 'hello'},
    'مرحبا': {'ar': 'مرحبا', 'ar_dz': 'مرحبا', 'de': 'hallo', 'en': 'hello'},
    'please': {'ar': 'من فضلك', 'ar_dz': 'من فضلك', 'de': 'bitte', 'en': 'please'},
    'bitte': {'ar': 'من فضلك', 'ar_dz': 'من فضلك', 'de': 'bitte', 'en': 'please'},
    'من فضلك': {'ar': 'من فضلك', 'ar_dz': 'من فضلك', 'de': 'bitte', 'en': 'please'},
    'thank you': {'ar': 'شكرا', 'ar_dz': 'شكرا', 'de': 'danke', 'en': 'thank you'},
    'danke': {'ar': 'شكرا', 'ar_dz': 'شكرا', 'de': 'danke', 'en': 'thank you'},
    'شكرا': {'ar': 'شكرا', 'ar_dz': 'شكرا', 'de': 'danke', 'en': 'thank you'},
  };


  /// Translates [text] into [targetLanguageCode].
  String translate(String text, {required String targetLanguageCode}) {
    final clean = text.trim();
    if (clean.isEmpty) return '';

    final target = targetLanguageCode.replaceAll('-', '_').toLowerCase();

    // 1. Direct corpus match
    for (final phrase in _phraseCorpus) {
      for (final entry in phrase.entries) {
        if (_normalize(entry.value) == _normalize(clean)) {
          return phrase[target] ?? clean;
        }
      }
    }

    // 2. Lexicon lookup for single words
    final normalizedWord = _normalize(clean);
    if (_wordLexicon.containsKey(normalizedWord)) {
      return _wordLexicon[normalizedWord]?[target] ?? clean;
    }

    return clean;
  }

  String _normalize(String s) {
    return s
        .replaceAll(RegExp(r'[.,!?؟]'), '')
        .trim()
        .toLowerCase();
  }
}
