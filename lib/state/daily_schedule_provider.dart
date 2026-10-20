/// Riverpod state management for Daily Schedules, Visual Routines, and First/Then pairs.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_schedule.dart';
import '../services/schedule/daily_schedule_store.dart';
import 'profile_provider.dart';

final dailyScheduleStoreProvider = Provider<DailyScheduleStore>((ref) {
  return DailyScheduleStore();
});

class DailyScheduleNotifier extends AsyncNotifier<DailySchedule> {
  Future<String> _getProfileId() async {
    final active = await ref.read(activeProfileProvider.future);
    return active.id;
  }

  @override
  Future<DailySchedule> build() async {
    final activeProfile = await ref.watch(activeProfileProvider.future);
    final store = ref.watch(dailyScheduleStoreProvider);
    return store.loadSchedule(activeProfile.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  Future<void> saveActivity(ScheduleActivity activity) async {
    final profileId = await _getProfileId();
    final store = ref.read(dailyScheduleStoreProvider);
    final current = await store.loadSchedule(profileId);

    final idx = current.activities.indexWhere((a) => a.id == activity.id);
    final updatedList = List<ScheduleActivity>.from(current.activities);
    if (idx >= 0) {
      updatedList[idx] = activity;
    } else {
      updatedList.add(activity);
    }

    final updated = current.copyWith(
      activities: updatedList,
      firstActivityId: current.firstActivityId ?? (updatedList.isNotEmpty ? updatedList.first.id : null),
      thenActivityId: current.thenActivityId ?? (updatedList.length > 1 ? updatedList[1].id : null),
    );

    await store.saveSchedule(profileId, updated);
    ref.invalidateSelf();
  }

  Future<void> deleteActivity(String activityId) async {
    final profileId = await _getProfileId();
    final store = ref.read(dailyScheduleStoreProvider);
    final current = await store.loadSchedule(profileId);

    final updatedList = current.activities.where((a) => a.id != activityId).toList();
    final updated = current.copyWith(
      activities: updatedList,
      firstActivityId: current.firstActivityId == activityId ? null : current.firstActivityId,
      thenActivityId: current.thenActivityId == activityId ? null : current.thenActivityId,
    );

    await store.saveSchedule(profileId, updated);
    ref.invalidateSelf();
  }

  Future<void> reorderActivities(int oldIndex, int newIndex) async {
    final profileId = await _getProfileId();
    final store = ref.read(dailyScheduleStoreProvider);
    final current = await store.loadSchedule(profileId);

    final updatedList = List<ScheduleActivity>.from(current.activities);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, item);

    final updated = current.copyWith(activities: updatedList);
    await store.saveSchedule(profileId, updated);
    ref.invalidateSelf();
  }

  Future<void> toggleCompleted(String activityId) async {
    final profileId = await _getProfileId();
    final store = ref.read(dailyScheduleStoreProvider);
    await store.toggleActivityCompleted(profileId: profileId, activityId: activityId);
    ref.invalidateSelf();
  }

  Future<void> applyTemplate(String templateId, {bool replace = false}) async {
    final profileId = await _getProfileId();
    final store = ref.read(dailyScheduleStoreProvider);
    await store.applyTemplate(profileId: profileId, templateId: templateId, replace: replace);
    ref.invalidateSelf();
  }

  Future<void> setFirstThen(String firstId, String thenId) async {
    final profileId = await _getProfileId();
    final store = ref.read(dailyScheduleStoreProvider);
    await store.setFirstThen(profileId: profileId, firstId: firstId, thenId: thenId);
    ref.invalidateSelf();
  }
}

final dailyScheduleProvider =
    AsyncNotifierProvider<DailyScheduleNotifier, DailySchedule>(
  DailyScheduleNotifier.new,
);

final scheduleTemplatesProvider = Provider<List<DailyScheduleTemplate>>((ref) {
  final store = ref.watch(dailyScheduleStoreProvider);
  return store.getTemplates();
});

final firstThenActivitiesProvider = Provider<({ScheduleActivity? first, ScheduleActivity? then})>((ref) {
  final schedule = ref.watch(dailyScheduleProvider).valueOrNull;
  if (schedule == null || schedule.activities.isEmpty) {
    return (first: null, then: null);
  }

  ScheduleActivity? first;
  ScheduleActivity? then;

  if (schedule.firstActivityId != null) {
    first = schedule.activities.where((a) => a.id == schedule.firstActivityId).firstOrNull;
  }
  if (schedule.thenActivityId != null) {
    then = schedule.activities.where((a) => a.id == schedule.thenActivityId).firstOrNull;
  }

  // Fallback to first incomplete and second incomplete
  final incomplete = schedule.activities.where((a) => !a.isCompleted).toList();
  first ??= incomplete.isNotEmpty ? incomplete.first : schedule.activities.first;
  then ??= incomplete.length > 1
      ? incomplete[1]
      : (schedule.activities.length > 1 ? schedule.activities[1] : null);

  return (first: first, then: then);
});
