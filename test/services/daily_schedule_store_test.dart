import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/daily_schedule.dart';
import 'package:lighthouse/services/schedule/daily_schedule_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late DailyScheduleStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('schedule_store_test_');
    store = DailyScheduleStore(baseDirOverride: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DailyScheduleStore Tests', () {
    test('seeds default schedule for new profile', () async {
      final schedule = await store.loadSchedule('profile_test_1');
      expect(schedule.profileId, equals('profile_test_1'));
      expect(schedule.activities, isNotEmpty);
      expect(schedule.firstActivityId, isNotNull);
      expect(schedule.thenActivityId, isNotNull);
    });

    test('profile isolation: separate profiles have distinct schedules', () async {
      final scheduleA = await store.loadSchedule('profile_a');

      const customActivityA = ScheduleActivity(
        id: 'act_custom_a',
        title: 'Sensory Swing',
        imageUri: '',
        category: ScheduleActivityCategory.therapy,
      );

      final updatedA = scheduleA.copyWith(
        activities: [...scheduleA.activities, customActivityA],
      );
      await store.saveSchedule('profile_a', updatedA);

      final reloadedA = await store.loadSchedule('profile_a');
      final reloadedB = await store.loadSchedule('profile_b');

      expect(reloadedA.activities.any((a) => a.id == 'act_custom_a'), isTrue);
      expect(reloadedB.activities.any((a) => a.id == 'act_custom_a'), isFalse);
    });

    test('toggleActivityCompleted updates completion flag', () async {
      final schedule = await store.loadSchedule('profile_toggle');
      final firstAct = schedule.activities.first;
      expect(firstAct.isCompleted, isFalse);

      await store.toggleActivityCompleted(
        profileId: 'profile_toggle',
        activityId: firstAct.id,
      );

      final updated = await store.loadSchedule('profile_toggle');
      final updatedFirstAct = updated.activities.firstWhere((a) => a.id == firstAct.id);
      expect(updatedFirstAct.isCompleted, isTrue);

      // Toggle back
      await store.toggleActivityCompleted(
        profileId: 'profile_toggle',
        activityId: firstAct.id,
      );
      final reverted = await store.loadSchedule('profile_toggle');
      final revertedAct = reverted.activities.firstWhere((a) => a.id == firstAct.id);
      expect(revertedAct.isCompleted, isFalse);
    });

    test('applyTemplate replaces or appends routine activities', () async {
      final initial = await store.loadSchedule('profile_template');
      final initialCount = initial.activities.length;

      // Apply school routine with append
      await store.applyTemplate(
        profileId: 'profile_template',
        templateId: 'school_routine',
        replace: false,
      );

      final appended = await store.loadSchedule('profile_template');
      expect(appended.activities.length, greaterThan(initialCount));

      // Apply hygiene routine with replace
      await store.applyTemplate(
        profileId: 'profile_template',
        templateId: 'hygiene_routine',
        replace: true,
      );

      final replaced = await store.loadSchedule('profile_template');
      expect(replaced.activities.every((a) => a.category == ScheduleActivityCategory.hygiene), isTrue);
    });

    test('setFirstThen configures First/Then sequence', () async {
      await store.setFirstThen(
        profileId: 'profile_ft',
        firstId: 'custom_first',
        thenId: 'custom_then',
      );

      final schedule = await store.loadSchedule('profile_ft');
      expect(schedule.firstActivityId, equals('custom_first'));
      expect(schedule.thenActivityId, equals('custom_then'));
    });

    test('getTemplates returns 6 pre-built clinical routines', () {
      final templates = store.getTemplates();
      expect(templates.length, equals(6));
      expect(templates.any((t) => t.id == 'morning_routine'), isTrue);
      expect(templates.any((t) => t.id == 'meals_routine'), isTrue);
      expect(templates.any((t) => t.id == 'school_routine'), isTrue);
      expect(templates.any((t) => t.id == 'therapy_routine'), isTrue);
      expect(templates.any((t) => t.id == 'hygiene_routine'), isTrue);
      expect(templates.any((t) => t.id == 'bedtime_routine'), isTrue);
    });
  });
}
