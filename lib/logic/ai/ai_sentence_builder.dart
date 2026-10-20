/// Offline AI Sentence Builder & Phrase Expander.
///
/// Transforms telegraphic AAC symbol selections into natural, grammatically
/// sound sentences across Arabic, Algerian Darija, German, and English.
///
/// Strictly offline, zero cloud dependencies, fully deterministic baseline.
library;

import '../../models/models.dart';

class AISentenceBuilder {
  const AISentenceBuilder();

  /// Generates a natural sentence in [languageCode] from a sequence of AAC [tokens].
  String buildSentence(List<AACButton> tokens, String languageCode) {
    if (tokens.isEmpty) return '';
    final code = languageCode.replaceAll('-', '_').toLowerCase();

    // Extract normalized token identifiers and words
    final ids = tokens.map((t) => t.id.toLowerCase()).toSet();
    final words = tokens
        .expand((t) => [t.label, ...t.labelByLocale.values, t.voiceOut ?? ''])
        .where((s) => s.isNotEmpty)
        .map((s) => s.trim().toLowerCase())
        .toSet();
    final all = {...ids, ...words};

    // 1. Communicative Intent Recognition
    // Thirsty / Drink Water
    final hasWater = all.any((w) =>
        w.contains('water') ||
        w.contains('ماء') ||
        w.contains('الما') ||
        w.contains('wasser'));
    final hasThirstIntent = all.any((w) =>
        w == 'i' ||
        w == 'btn_i' ||
        w.contains('ich') ||
        w.contains('أنا') ||
        w.contains('want') ||
        w.contains('need') ||
        w.contains('drink') ||
        w.contains('حاب') ||
        w.contains('أريد') ||
        w.contains('نشرب') ||
        w.contains('trinken') ||
        w.contains('möchte'));

    if (hasWater && hasThirstIntent) {
      return switch (code) {
        'ar' => 'أريد أن أشرب الماء.',
        'ar_dz' => 'حاب نشرب الماء.',
        'de' => 'Ich möchte Wasser trinken.',
        _ => 'I want to drink water.',
      };
    }


    // Hungry / Eat
    if (ids.contains('btn_hungry') ||
        ((ids.contains('btn_eat') || ids.contains('btn_food_folder') || words.any((w) => w.contains('bread') || w.contains('food') || w.contains('خبز') || w.contains('طعام') || w.contains('essen'))) &&
            (ids.contains('btn_i') || ids.contains('btn_want') || ids.contains('btn_need')))) {
      if (ids.contains('btn_hungry')) {
        return switch (code) {
          'ar' => 'أنا جائع جدًا.',
          'ar_dz' => 'راني جيعان بزاف.',
          'de' => 'Ich habe Hunger.',
          _ => 'I am hungry.',
        };
      }
      return switch (code) {
        'ar' => 'أريد أن آكل.',
        'ar_dz' => 'حاب ناكل.',
        'de' => 'Ich möchte essen.',
        _ => 'I want to eat.',
      };
    }

    // Tired / Sleep
    if (ids.contains('btn_tired') ||
        (ids.contains('btn_act_sleep') && (ids.contains('btn_i') || ids.contains('btn_want')))) {
      return switch (code) {
        'ar' => 'أنا متعب وأريد أن أنام.',
        'ar_dz' => 'راني تعبان وحاب نرقد.',
        'de' => 'Ich bin müde und möchte schlafen.',
        _ => 'I am tired and want to sleep.',
      };
    }

    // Help
    if (ids.contains('btn_help')) {
      return switch (code) {
        'ar' => 'ساعدني من فضلك.',
        'ar_dz' => 'عاونّي من فضلك.',
        'de' => 'Bitte hilf mir.',
        _ => 'Please help me.',
      };
    }

    // Go Home
    if (ids.contains('btn_home') && (ids.contains('btn_go') || ids.contains('btn_want') || ids.contains('btn_i'))) {
      return switch (code) {
        'ar' => 'أريد الذهاب إلى المنزل.',
        'ar_dz' => 'حاب نروح للدار.',
        'de' => 'Ich möchte nach Hause gehen.',
        _ => 'I want to go home.',
      };
    }

    // Questions: What is this?
    if (ids.contains('btn_what') || (ids.contains('btn_that') && ids.contains('btn_what'))) {
      return switch (code) {
        'ar' => 'ما هذا؟',
        'ar_dz' => 'واش هذا؟',
        'de' => 'Was ist das?',
        _ => 'What is this?',
      };
    }

    // Feelings: Happy
    if (ids.contains('btn_happy') || (ids.contains('btn_feel_excited'))) {
      return switch (code) {
        'ar' => 'أنا سعيد ومتحمس.',
        'ar_dz' => 'راني فرحان بزاف.',
        'de' => 'Ich bin sehr glücklich.',
        _ => 'I feel happy.',
      };
    }

    // Feelings: Sad / Hurt
    if (ids.contains('btn_hurt') || ids.contains('btn_feel_sick')) {
      return switch (code) {
        'ar' => 'أشعر بالألم والمرض.',
        'ar_dz' => 'يوجعني وراني مريض.',
        'de' => 'Ich habe Schmerzen und bin krank.',
        _ => 'I am in pain and feel sick.',
      };
    }

    // Did not understand
    if (ids.contains('btn_feel_confused')) {
      return switch (code) {
        'ar' => 'لم أفهم هذا.',
        'ar_dz' => 'ما فهمتش هاد الشي.',
        'de' => 'Ich verstehe das nicht.',
        _ => "I didn't understand.",
      };
    }

    // 2. Syntactic grammar fallthrough
    final voiceTokens = tokens
        .where((t) => t.type != AACButtonType.folder)
        .map((t) => t.voiceOutFor(code) ?? t.labelFor(code))
        .where((w) => w.isNotEmpty)
        .toList();

    if (voiceTokens.isEmpty) return '';

    return _synthesizeNaturalFlow(voiceTokens, code);
  }

  /// Expands raw tokens into natural syntax for general phrases
  String _synthesizeNaturalFlow(List<String> words, String code) {
    if (words.isEmpty) return '';
    if (words.length == 1) {
      final w = words.first;
      return code == 'ar' || code == 'ar_dz'
          ? w
          : '${w[0].toUpperCase()}${w.substring(1)}.';
    }

    final raw = words.join(' ');
    if (code == 'en') {
      return '${raw[0].toUpperCase()}${raw.substring(1)}.';
    } else if (code == 'de') {
      return '${raw[0].toUpperCase()}${raw.substring(1)}.';
    } else {
      return '$raw.';
    }
  }
}
