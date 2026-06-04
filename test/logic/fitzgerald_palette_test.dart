import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lighthouse/logic/logic.dart';

void main() {
  group('parseHexColor', () {
    test('parses #RRGGBB with leading #', () {
      expect(parseHexColor('#FFFFA6'), const Color(0xFFFFFFA6));
    });

    test('parses RRGGBB without #', () {
      expect(parseHexColor('C2FFC2'), const Color(0xFFC2FFC2));
    });

    test('parses 8-digit #AARRGGBB', () {
      expect(parseHexColor('#80FFFFA6'), const Color(0x80FFFFA6));
    });

    test('returns null on garbage', () {
      expect(parseHexColor('not-a-color'), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(parseHexColor('#FFF'), isNull, reason: 'short form not allowed');
    });
  });

  group('resolveCategoryColor', () {
    const colorKey = {
      'verb': '#C2FFC2',
      'needs': '#FFC2C2',
      'malformed': 'not-a-hex',
    };
    const fallback = Color(0xFFCCCCCC);

    test('resolves a known category', () {
      expect(
        resolveCategoryColor('verb', colorKey, fallback: fallback),
        const Color(0xFFC2FFC2),
      );
    });

    test('falls back when category is missing', () {
      expect(
        resolveCategoryColor('unknown', colorKey, fallback: fallback),
        fallback,
      );
    });

    test('falls back when hex is malformed', () {
      expect(
        resolveCategoryColor('malformed', colorKey, fallback: fallback),
        fallback,
      );
    });
  });
}
