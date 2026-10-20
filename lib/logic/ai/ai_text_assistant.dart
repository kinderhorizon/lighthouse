/// Offline AI Text Assistant for typed AAC communication.
///
/// Takes partial typed text or shorthand queries and generates full natural
/// sentence candidates across Arabic, Algerian Darija, German, and English.
library;

class AITextAssistant {
  const AITextAssistant();

  static const List<Map<String, String>> _sentenceTemplates = [
    {
      'en': 'I want to drink water.',
      'ar': 'أريد أن أشرب الماء.',
      'ar_dz': 'حاب نشرب الماء.',
      'de': 'Ich möchte Wasser trinken.',
      'keywords': 'water drink thirst ماء ما اشرب عطشان wasser trinken',
    },
    {
      'en': 'I am thirsty and need water.',
      'ar': 'أنا عطشان وأريد الماء.',
      'ar_dz': 'راني عطشان وحاب نشرب الماء.',
      'de': 'Ich bin durstig und brauche Wasser.',
      'keywords': 'thirsty drink water عطشان نشرب راني durst',
    },
    {
      'en': 'I am hungry and want to eat.',
      'ar': 'أنا جائع وأريد أن آكل.',
      'ar_dz': 'راني جيعان وحاب ناكل.',
      'de': 'Ich habe Hunger und möchte essen.',
      'keywords': 'hungry eat food اكل جائع جيعان ماكلة essen hunger ich habe hunger brot',
    },
    {
      'en': 'I want to eat.',
      'ar': 'أريد أن آكل.',
      'ar_dz': 'حاب ناكل.',
      'de': 'Ich möchte essen.',
      'keywords': 'i want to eat hunger essen اكل ناكل',
    },
    {
      'en': 'I feel happy today.',
      'ar': 'أنا سعيد اليوم.',
      'ar_dz': 'راني فرحان اليوم.',
      'de': 'Ich bin heute glücklich.',
      'keywords': 'happy glad فرحان سعيد راني gluecklich',
    },

    {
      'en': 'Please help me with this.',
      'ar': 'ساعدني من فضلك.',
      'ar_dz': 'عاونّي من فضلك.',
      'de': 'Bitte hilf mir dabei.',
      'keywords': 'help please مساعدة ساعد عاون عيشك hilfe bitte',
    },
    {
      'en': 'I am tired and want to rest.',
      'ar': 'أنا متعب وأريد أن أستريح.',
      'ar_dz': 'راني تعبان وحاب نريح.',
      'de': 'Ich bin müde und möchte mich ausruhen.',
      'keywords': 'tired sleep rest متعب تعبان نوم رقاد muede schlafen pause',
    },
    {
      'en': 'I want to go home now.',
      'ar': 'أريد الذهاب إلى المنزل الآن.',
      'ar_dz': 'حاب نروح للدار درك.',
      'de': 'Ich möchte jetzt nach Hause gehen.',
      'keywords': 'home go house منزل دار نروح نروحو nach hause heim',
    },
    {
      'en': 'I need to use the bathroom.',
      'ar': 'أحتاج للذهاب إلى الحمام.',
      'ar_dz': 'حاب نروح لبيت الما.',
      'de': 'Ich muss zur Toilette gehen.',
      'keywords': 'bathroom toilet حمام بيت الما مرحاض toilette wc',
    },
    {
      'en': 'What is this?',
      'ar': 'ما هذا؟',
      'ar_dz': 'واش هذا؟',
      'de': 'Was ist das?',
      'keywords': 'what this ماذا ما هذا واش واشنو was das',
    },
    {
      'en': 'Thank you very much.',
      'ar': 'شكرًا جزيلاً لك.',
      'ar_dz': 'يعطيك الصحة بزاف.',
      'de': 'Vielen herzlichen Dank.',
      'keywords': 'thank thanks شكرا صحة يعطيك danke dankschoen',
    },
  ];

  /// Suggests complete, natural sentences matching the typed [query] in [languageCode].
  List<String> getSuggestions(String query, String languageCode) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];

    final target = languageCode.replaceAll('-', '_').toLowerCase();
    final results = <String>[];

    for (final template in _sentenceTemplates) {
      final keywords = template['keywords'] ?? '';
      final sentence = template[target] ?? template['en'] ?? '';

      if (keywords.toLowerCase().contains(clean) ||
          sentence.toLowerCase().contains(clean)) {
        if (!results.contains(sentence)) {
          results.add(sentence);
        }
      }
    }

    // If query is an incomplete sentence without a keyword hit, offer a capitalized polite form
    if (results.isEmpty && clean.isNotEmpty) {
      if (target == 'ar' || target == 'ar_dz') {
        results.add('$query من فضلك.');
      } else if (target == 'de') {
        results.add('Bitte $query.');
      } else {
        results.add('Please $query.');
      }
    }

    return results;
  }
}
