import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/ai/ai.dart';
import 'package:lighthouse/models/models.dart';

void main() {
  AACButton btn(
    String id,
    String label, {
    String? labelArDz,
    String? labelDe,
    String? labelEn,
  }) {
    return AACButton(
      id: id,
      label: label,
      labelByLocale: {
        if (labelArDz != null) 'ar_dz': labelArDz,
        if (labelDe != null) 'de': labelDe,
        if (labelEn != null) 'en': labelEn,
      },
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: 'needs',
      baseWeight: 1.0,
      voiceOut: label,
      voiceOutByLocale: {
        if (labelArDz != null) 'ar_dz': labelArDz,
        if (labelDe != null) 'de': labelDe,
        if (labelEn != null) 'en': labelEn,
      },
      iconUri: 'test.svg',
    );
  }

  group('AISentenceBuilder tests', () {
    const builder = AISentenceBuilder();

    test('Expands Arabic telegraphic input [أنا, ماء] to natural sentence', () {
      final tokens = [
        btn('i', 'أنا', labelArDz: 'أنا'),
        btn('water', 'ماء', labelArDz: 'الماء'),
      ];
      final sentenceAr = builder.buildSentence(tokens, 'ar');
      expect(sentenceAr, equals('أريد أن أشرب الماء.'));
    });

    test('Expands Algerian Darija input [أنا, ماء] to natural Darija phrase', () {
      final tokens = [
        btn('i', 'أنا', labelArDz: 'أنا'),
        btn('water', 'ماء', labelArDz: 'الماء'),
      ];
      final sentenceDz = builder.buildSentence(tokens, 'ar_dz');
      expect(sentenceDz, equals('حاب نشرب الماء.'));
    });

    test('Expands German telegraphic input [ich, wasser] to natural German sentence', () {
      final tokens = [
        btn('i', 'Ich', labelDe: 'ich'),
        btn('water', 'Wasser', labelDe: 'Wasser'),
      ];
      final sentenceDe = builder.buildSentence(tokens, 'de');
      expect(sentenceDe, equals('Ich möchte Wasser trinken.'));
    });

    test('Expands English telegraphic input [I, water] to natural English sentence', () {
      final tokens = [
        btn('i', 'I', labelEn: 'I'),
        btn('water', 'water', labelEn: 'water'),
      ];
      final sentenceEn = builder.buildSentence(tokens, 'en');
      expect(sentenceEn, equals('I want to drink water.'));
    });

    test('Handles single token or unknown pattern gracefully', () {
      final singleToken = [btn('hello', 'مرحبا')];
      expect(builder.buildSentence(singleToken, 'ar'), equals('مرحبا'));

      final randomTokens = [btn('sun', 'شمس'), btn('tree', 'شجرة')];
      expect(builder.buildSentence(randomTokens, 'ar'), equals('شمس شجرة.'));
    });
  });

  group('AIMultilingualTranslator tests', () {
    const translator = AIMultilingualTranslator();

    test('Translates clinical Darija phrases to German and English', () {
      final en = translator.translate('حاب نشرب الماء', targetLanguageCode: 'en');
      expect(en, equals('I want to drink water.'));

      final de = translator.translate('حاب نشرب الماء', targetLanguageCode: 'de');
      expect(de, equals('Ich möchte Wasser trinken.'));
    });

    test('Translates hunger/thirst phrases to Algerian Darija', () {
      final dzHungry = translator.translate('I am hungry', targetLanguageCode: 'ar_dz');
      expect(dzHungry, equals('راني جيعان.'));
    });

    test('Translates core greeting and manners words across languages', () {
      expect(translator.translate('hello', targetLanguageCode: 'de'), equals('hallo'));
      expect(translator.translate('hello', targetLanguageCode: 'ar'), equals('مرحبا'));
      expect(translator.translate('please', targetLanguageCode: 'ar_dz'), equals('من فضلك'));
      expect(translator.translate('thank you', targetLanguageCode: 'ar_dz'), equals('يعطيك الصحة.'));
    });
  });

  group('AITextAssistant tests', () {
    const assistant = AITextAssistant();

    test('Suggests autocompletions for Algerian Darija queries', () {
      final suggestions = assistant.getSuggestions('راني', 'ar_dz');
      expect(suggestions.any((s) => s.contains('عطشان')), isTrue);
      expect(suggestions.any((s) => s.contains('جيعان')), isTrue);
      expect(suggestions.any((s) => s.contains('فرحان')), isTrue);
      expect(suggestions.any((s) => s.contains('تعبان')), isTrue);
    });

    test('Suggests autocompletions for German queries', () {
      final suggestions = assistant.getSuggestions('Ich', 'de');
      expect(suggestions.any((s) => s.contains('Wasser trinken')), isTrue);
      expect(suggestions.any((s) => s.contains('Hunger')), isTrue);
    });

    test('Suggests autocompletions for English queries', () {
      final suggestions = assistant.getSuggestions('I want', 'en');
      expect(suggestions.any((s) => s.contains('drink water')), isTrue);
      expect(suggestions.any((s) => s.contains('eat')), isTrue);
      expect(suggestions.any((s) => s.contains('go home')), isTrue);
    });
  });

  group('AIWordPredictor tests', () {
    const predictor = AIWordPredictor();

    final testBoard = AACBoard(
      schemaVersion: '1.0',
      boardId: 'test_board',
      boardName: 'Test',
      gridDimensions: (rows: 2, cols: 3),
      colorKey: {},
      buttons: [
        btn('i', 'أنا', labelArDz: 'أنا'),
        btn('want', 'أريد', labelArDz: 'حاب'),
        btn('water', 'ماء', labelArDz: 'الماء'),
        btn('food', 'طعام', labelArDz: 'الماكلة'),
      ],
    );

    test('Predicts relevant next words given previous token', () {
      final preceding = <AACButton>[testBoard.buttons.firstWhere((b) => b.id == 'i')];
      final candidates = predictor.predictNextWords(
        precedingTokens: preceding,
        board: testBoard,
        limit: 3,
      );

      expect(candidates, isNotEmpty);
      expect(candidates.any((b) => b.id == 'want' || b.id == 'water' || b.id == 'food'), isTrue);
    });

    test('Provides fallback candidates when no previous token exists', () {
      final candidates = predictor.predictNextWords(
        precedingTokens: const <AACButton>[],
        board: testBoard,
        limit: 2,
      );

      expect(candidates.length, lessThanOrEqualTo(2));
      expect(candidates, isNotEmpty);
    });
  });
}
