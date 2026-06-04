import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';

void main() {
  group('AACButton.fromJson', () {
    test('parses a word button with localized labels and voice-out', () {
      final btn = AACButton.fromJson({
        'id': 'btn_want',
        'label': 'Want',
        'label_ar': 'أريد',
        'label_es': 'Quiero',
        'type': 'word',
        'voice_out': 'want',
        'voice_out_ar': 'أريد',
        'voice_out_es': 'quiero',
        'position': {'row': 0, 'col': 2},
        'category': 'verb',
        'base_weight': 0.8,
        'icon_uri': 'assets/arasaac/verbs/want.webp',
      });

      expect(btn.id, 'btn_want');
      expect(btn.label, 'Want');
      expect(btn.labelFor('ar'), 'أريد');
      expect(btn.labelFor('es'), 'Quiero');
      expect(btn.labelFor('fr'), 'Want', reason: 'falls back to default');
      expect(btn.type, AACButtonType.word);
      expect(btn.voiceOutFor('es'), 'quiero');
      expect(btn.position, (row: 0, col: 2));
      expect(btn.category, 'verb');
      expect(btn.baseWeight, 0.8);
      expect(btn.linkId, isNull);
    });

    test('parses a phrase button', () {
      final btn = AACButton.fromJson({
        'id': 'btn_help',
        'label': 'Help',
        'type': 'phrase',
        'voice_out': 'I need help',
        'position': {'row': 0, 'col': 5},
        'category': 'needs',
        'base_weight': 0.9,
        'icon_uri': 'assets/arasaac/needs/help.webp',
      });
      expect(btn.type, AACButtonType.phrase);
      expect(btn.voiceOut, 'I need help');
    });

    test('parses a folder button with link_id and null voice_out', () {
      final btn = AACButton.fromJson({
        'id': 'btn_food_folder',
        'label': 'Food',
        'type': 'folder',
        'link_id': 'board_food',
        'position': {'row': 4, 'col': 0},
        'category': 'food_nav',
        'base_weight': 0.6,
        'icon_uri': 'assets/arasaac/folders/food.webp',
      });
      expect(btn.type, AACButtonType.folder);
      expect(btn.linkId, 'board_food');
      expect(btn.voiceOut, isNull);
      expect(btn.voiceOutFor('ar'), isNull);
    });

    test('throws FormatException on missing id', () {
      expect(
        () => AACButton.fromJson({
          'label': 'X',
          'type': 'word',
          'position': {'row': 0, 'col': 0},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on unknown type', () {
      expect(
        () => AACButton.fromJson({
          'id': 'btn_x',
          'label': 'X',
          'type': 'gibberish',
          'position': {'row': 0, 'col': 0},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException on malformed position', () {
      expect(
        () => AACButton.fromJson({
          'id': 'btn_x',
          'label': 'X',
          'type': 'word',
          'position': {'row': 'first', 'col': 'second'},
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('AACButtonType.fromJson rejects unknown values', () {
      expect(() => AACButtonType.fromJson(''),
          throwsA(isA<FormatException>()));
      expect(() => AACButtonType.fromJson('SENTENCE'),
          throwsA(isA<FormatException>()));
    });
  });
}
