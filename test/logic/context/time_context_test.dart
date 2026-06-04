import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';

void main() {
  group('timeBlockFor', () {
    test('Morning is hours 6 through 8', () {
      expect(timeBlockFor(DateTime(2026, 5, 28, 6)), TimeBlock.morning);
      expect(timeBlockFor(DateTime(2026, 5, 28, 8, 59)), TimeBlock.morning);
    });
    test('School is hours 9 through 13', () {
      expect(timeBlockFor(DateTime(2026, 5, 28, 9)), TimeBlock.school);
      expect(timeBlockFor(DateTime(2026, 5, 28, 13, 59)), TimeBlock.school);
    });
    test('Afternoon is hours 14 through 16', () {
      expect(timeBlockFor(DateTime(2026, 5, 28, 14)), TimeBlock.afternoon);
      expect(
          timeBlockFor(DateTime(2026, 5, 28, 16, 59)), TimeBlock.afternoon);
    });
    test('Dinner is hours 17 through 19', () {
      expect(timeBlockFor(DateTime(2026, 5, 28, 17)), TimeBlock.dinner);
      expect(timeBlockFor(DateTime(2026, 5, 28, 19, 59)), TimeBlock.dinner);
    });
    test('Night covers 20 through 5 the next morning', () {
      expect(timeBlockFor(DateTime(2026, 5, 28, 20)), TimeBlock.night);
      expect(timeBlockFor(DateTime(2026, 5, 28, 23, 59)), TimeBlock.night);
      expect(timeBlockFor(DateTime(2026, 5, 29, 0)), TimeBlock.night);
      expect(timeBlockFor(DateTime(2026, 5, 29, 5, 59)), TimeBlock.night);
    });
    test('boundary at 6 AM flips Night -> Morning', () {
      expect(timeBlockFor(DateTime(2026, 5, 29, 5, 59)), TimeBlock.night);
      expect(timeBlockFor(DateTime(2026, 5, 29, 6)), TimeBlock.morning);
    });
  });

  group('dayTypeFor (locale-aware weekend)', () {
    // 2026-05-29 = Friday. 2026-05-30 = Saturday. 2026-05-31 = Sunday.
    final friday = DateTime(2026, 5, 29);
    final saturday = DateTime(2026, 5, 30);
    final sunday = DateTime(2026, 5, 31);
    final monday = DateTime(2026, 6, 1);

    test('en locale: Sat + Sun are weekend', () {
      const en = Locale('en');
      expect(dayTypeFor(friday, en), DayType.weekday);
      expect(dayTypeFor(saturday, en), DayType.weekend);
      expect(dayTypeFor(sunday, en), DayType.weekend);
      expect(dayTypeFor(monday, en), DayType.weekday);
    });
    test('ar locale: Fri + Sat are weekend', () {
      const ar = Locale('ar');
      expect(dayTypeFor(friday, ar), DayType.weekend);
      expect(dayTypeFor(saturday, ar), DayType.weekend);
      expect(dayTypeFor(sunday, ar), DayType.weekday);
    });
    test('Hebrew locale: Fri + Sat are weekend', () {
      const he = Locale('he');
      expect(dayTypeFor(friday, he), DayType.weekend);
      expect(dayTypeFor(saturday, he), DayType.weekend);
      expect(dayTypeFor(sunday, he), DayType.weekday);
    });
    test('Spanish locale (en family): Sat + Sun are weekend', () {
      const es = Locale('es');
      expect(dayTypeFor(friday, es), DayType.weekday);
      expect(dayTypeFor(saturday, es), DayType.weekend);
    });
  });
}
