import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/daily_schedule.dart';

void main() {
  group('DailySchedule & ScheduleActivity Model Tests', () {
    test('serializes and deserializes ScheduleActivity via JSON', () {
      const act = ScheduleActivity(
        id: 'act_101',
        title: 'Morning Teeth Brushing',
        time: '08:15',
        durationMinutes: 10,
        category: ScheduleActivityCategory.hygiene,
        imageUri: 'assets/symbols/actions/wash.png',
        isCompleted: true,
        labelsByLocale: {
          'en': 'Brush Teeth',
          'de': 'Zähne putzen',
          'ar': 'تنظيف الأسنان',
          'ar_dz': 'غسل السنان',
        },
        speechByLocale: {
          'en': 'Time to brush your teeth',
          'de': 'Zeit Zähne zu putzen',
          'ar': 'حان وقت تنظيف الأسنان',
          'ar_dz': 'وقت باش نغسل سناني',
        },
      );

      final json = act.toJson();
      final restored = ScheduleActivity.fromJson(json);

      expect(restored.id, equals('act_101'));
      expect(restored.title, equals('Morning Teeth Brushing'));
      expect(restored.time, equals('08:15'));
      expect(restored.durationMinutes, equals(10));
      expect(restored.category, equals(ScheduleActivityCategory.hygiene));
      expect(restored.imageUri, equals('assets/symbols/actions/wash.png'));
      expect(restored.isCompleted, isTrue);
      expect(restored.labelFor('de'), equals('Zähne putzen'));
      expect(restored.labelFor('ar'), equals('تنظيف الأسنان'));
      expect(restored.labelFor('ar_dz'), equals('غسل السنان'));
      expect(restored.speechFor('ar_dz'), equals('وقت باش نغسل سناني'));
    });

    test('serializes and deserializes DailySchedule via JSON', () {
      const schedule = DailySchedule(
        id: 'sched_1',
        profileId: 'user_123',
        date: '2026-10-19',
        firstActivityId: 'act_1',
        thenActivityId: 'act_2',
        activities: [
          ScheduleActivity(
            id: 'act_1',
            title: 'Eat Breakfast',
            time: '08:30',
            imageUri: 'assets/symbols/food/food.png',
            durationMinutes: 20,
            category: ScheduleActivityCategory.meal,
          ),
          ScheduleActivity(
            id: 'act_2',
            title: 'Go to School',
            time: '09:00',
            imageUri: 'assets/symbols/places/school.png',
            durationMinutes: 30,
            category: ScheduleActivityCategory.school,
          ),
        ],
      );

      final json = schedule.toJson();
      final restored = DailySchedule.fromJson(json);

      expect(restored.profileId, equals('user_123'));
      expect(restored.date, equals('2026-10-19'));
      expect(restored.firstActivityId, equals('act_1'));
      expect(restored.thenActivityId, equals('act_2'));
      expect(restored.activities.length, equals(2));
      expect(restored.activities.first.title, equals('Eat Breakfast'));
      expect(restored.activities.last.category, equals(ScheduleActivityCategory.school));
    });

    test('fallback behavior when translations are missing', () {
      const act = ScheduleActivity(
        id: 'act_simple',
        title: 'Story Time',
        imageUri: '',
        category: ScheduleActivityCategory.leisure,
      );

      expect(act.labelFor('fr'), equals('Story Time'));
      expect(act.labelFor('de'), equals('Story Time'));
      expect(act.speechFor('ar'), equals('Story Time'));
    });

    test('category colors follow clinical palette', () {
      for (final cat in ScheduleActivityCategory.all) {
        final color = ScheduleActivityCategory.colorFor(cat);
        expect((color.a * 255.0).round(), equals(255));
      }
    });
  });
}
