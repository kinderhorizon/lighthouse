/// Domain models for Daily Schedules, Visual Routines, and First/Then schedules.
library;

import 'package:flutter/material.dart';

/// Predefined category keys for visual schedule activities.
class ScheduleActivityCategory {
  static const String routine = 'routine';
  static const String meal = 'meal';
  static const String school = 'school';
  static const String therapy = 'therapy';
  static const String hygiene = 'hygiene';
  static const String bedtime = 'bedtime';
  static const String leisure = 'leisure';
  static const String custom = 'custom';

  static const List<String> all = [
    routine,
    meal,
    school,
    therapy,
    hygiene,
    bedtime,
    leisure,
    custom,
  ];

  /// Checks if [category] matches any known standard routine category.
  static bool isValid(String? category) {
    if (category == null) return false;
    return all.contains(category.toLowerCase().trim());
  }

  /// Normalizes [category], mapping null, empty, or unrecognized values safely to [routine] or [custom].
  static String normalize(String? category) {
    if (category == null || category.trim().isEmpty) {
      return routine;
    }
    final normalized = category.toLowerCase().trim();
    if (all.contains(normalized)) {
      return normalized;
    }
    return custom;
  }

  /// Clinical color key matching Fitzgerald Key AAC conventions.
  static Color colorFor(String category) {
    switch (category) {
      case routine:
        return const Color(0xFFFFE599); // Light yellow
      case meal:
        return const Color(0xFFFFD5B8); // Warm peach / orange
      case school:
        return const Color(0xFFD9E8F5); // Soft blue
      case therapy:
        return const Color(0xFFD5E8D4); // Soft green
      case hygiene:
        return const Color(0xFFE1D5E7); // Soft purple
      case bedtime:
        return const Color(0xFFB3D1FF); // Calm bedtime blue
      case leisure:
        return const Color(0xFFFFF2CC); // Soft amber
      case custom:
      default:
        return const Color(0xFFEFEFEF); // Calm grey
    }
  }

  /// Category name in UI.
  static String nameFor(String category, String localeCode) {
    final isAr = localeCode.startsWith('ar');
    final isDe = localeCode.startsWith('de');

    switch (category) {
      case routine:
        return isAr ? 'روتين' : (isDe ? 'Routine' : 'Routine');
      case meal:
        return isAr ? 'وجبة' : (isDe ? 'Mahlzeit' : 'Meal');
      case school:
        return isAr ? 'مدرسة' : (isDe ? 'Schule' : 'School');
      case therapy:
        return isAr ? 'علاج' : (isDe ? 'Therapie' : 'Therapy');
      case hygiene:
        return isAr ? 'نظافة' : (isDe ? 'Hygiene' : 'Hygiene');
      case bedtime:
        return isAr ? 'نوم' : (isDe ? 'Schlafenszeit' : 'Bedtime');
      case leisure:
        return isAr ? 'ترفيه' : (isDe ? 'Freizeit' : 'Leisure');
      case custom:
      default:
        return isAr ? 'مخصص' : (isDe ? 'Benutzerdefiniert' : 'Custom');
    }
  }
}

/// Represents an activity item in a daily visual schedule.
class ScheduleActivity {
  const ScheduleActivity({
    required this.id,
    required this.title,
    this.speechText,
    this.time,
    required this.imageUri,
    this.isCompleted = false,
    this.category = ScheduleActivityCategory.routine,
    this.labelsByLocale = const {},
    this.speechByLocale = const {},
    this.durationMinutes = 15,
    this.notes,
  });

  final String id;
  final String title;
  final String? speechText;
  final String? time; // e.g. "08:30" or "Morning"
  final String imageUri;
  final bool isCompleted;
  final String category;
  final Map<String, String> labelsByLocale;
  final Map<String, String> speechByLocale;
  final int durationMinutes;
  final String? notes;

  /// Alias for imageUri to align with AACButton iconography conventions.
  String get iconUri => imageUri;

  /// Resolves the displayed label for a given language code.
  String labelFor(String localeCode) {
    final normalized = localeCode.replaceAll('-', '_').toLowerCase();
    if (labelsByLocale.containsKey(normalized)) {
      return labelsByLocale[normalized]!;
    }
    final prefix = normalized.split('_').first;
    for (final key in labelsByLocale.keys) {
      if (key.toLowerCase().startsWith(prefix)) {
        return labelsByLocale[key]!;
      }
    }
    return title;
  }

  /// Resolves the spoken text for TTS in a given language code.
  String speechFor(String localeCode) {
    final normalized = localeCode.replaceAll('-', '_').toLowerCase();
    if (speechByLocale.containsKey(normalized)) {
      return speechByLocale[normalized]!;
    }
    final prefix = normalized.split('_').first;
    for (final key in speechByLocale.keys) {
      if (key.toLowerCase().startsWith(prefix)) {
        return speechByLocale[key]!;
      }
    }
    return speechText ?? labelFor(localeCode);
  }

  ScheduleActivity copyWith({
    String? id,
    String? title,
    String? speechText,
    String? time,
    String? imageUri,
    bool? isCompleted,
    String? category,
    Map<String, String>? labelsByLocale,
    Map<String, String>? speechByLocale,
    int? durationMinutes,
    String? notes,
  }) {
    return ScheduleActivity(
      id: id ?? this.id,
      title: title ?? this.title,
      speechText: speechText ?? this.speechText,
      time: time ?? this.time,
      imageUri: imageUri ?? this.imageUri,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
      labelsByLocale: labelsByLocale ?? this.labelsByLocale,
      speechByLocale: speechByLocale ?? this.speechByLocale,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'speech_text': speechText,
        'time': time,
        'image_uri': imageUri,
        'is_completed': isCompleted,
        'category': category,
        'labels_by_locale': labelsByLocale,
        'speech_by_locale': speechByLocale,
        'duration_minutes': durationMinutes,
        'notes': notes,
      };

  factory ScheduleActivity.fromJson(Map<String, dynamic> json) {
    var imageUri = json['image_uri']?.toString() ?? '';
    // Guard against oversized inline base64 attachments (>5MB)
    if (imageUri.startsWith('data:') && imageUri.length > 5 * 1024 * 1024) {
      imageUri = 'assets/symbols/activities/sleep.png';
    }

    return ScheduleActivity(
      id: json['id']?.toString() ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Activity',
      speechText: json['speech_text']?.toString(),
      time: json['time']?.toString(),
      imageUri: imageUri,
      isCompleted: json['is_completed'] == true,
      category: ScheduleActivityCategory.normalize(json['category']?.toString()),
      labelsByLocale: (json['labels_by_locale'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
      speechByLocale: (json['speech_by_locale'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 15,
      notes: json['notes']?.toString(),
    );
  }
}

/// A complete daily visual schedule containing an ordered list of activities.
class DailySchedule {
  const DailySchedule({
    required this.id,
    required this.profileId,
    required this.date,
    required this.activities,
    this.firstActivityId,
    this.thenActivityId,
  });

  final String id;
  final String profileId;
  final String date; // YYYY-MM-DD
  final List<ScheduleActivity> activities;
  final String? firstActivityId;
  final String? thenActivityId;

  DailySchedule copyWith({
    String? id,
    String? profileId,
    String? date,
    List<ScheduleActivity>? activities,
    String? firstActivityId,
    String? thenActivityId,
  }) {
    return DailySchedule(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      date: date ?? this.date,
      activities: activities ?? this.activities,
      firstActivityId: firstActivityId ?? this.firstActivityId,
      thenActivityId: thenActivityId ?? this.thenActivityId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile_id': profileId,
        'date': date,
        'activities': activities.map((a) => a.toJson()).toList(),
        'first_activity_id': firstActivityId,
        'then_activity_id': thenActivityId,
      };

  factory DailySchedule.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'];
    final activitiesList = <ScheduleActivity>[];
    if (rawActivities is List) {
      for (final item in rawActivities) {
        if (item is Map<String, dynamic>) {
          try {
            activitiesList.add(ScheduleActivity.fromJson(item));
          } catch (_) {}
        }
      }
    }

    final pId = json['profile_id']?.toString() ?? 'default';
    final dStr = json['date']?.toString() ?? 'today';

    return DailySchedule(
      id: json['id']?.toString() ?? 'schedule_${pId}_$dStr',
      profileId: pId,
      date: dStr,
      activities: activitiesList,
      firstActivityId: json['first_activity_id']?.toString(),
      thenActivityId: json['then_activity_id']?.toString(),
    );
  }
}

/// A pre-made routine template that can be loaded with one tap.
class DailyScheduleTemplate {
  const DailyScheduleTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.activities,
    this.namesByLocale = const {},
  });

  final String id;
  final String name;
  final String category;
  final List<ScheduleActivity> activities;
  final Map<String, String> namesByLocale;

  String localizedName(String localeCode) {
    final normalized = localeCode.replaceAll('-', '_').toLowerCase();
    if (namesByLocale.containsKey(normalized)) {
      return namesByLocale[normalized]!;
    }
    final prefix = normalized.split('_').first;
    for (final key in namesByLocale.keys) {
      if (key.toLowerCase().startsWith(prefix)) {
        return namesByLocale[key]!;
      }
    }
    return name;
  }

  String titleFor(String localeCode) => localizedName(localeCode);

  String descriptionFor(String localeCode) =>
      '${activities.length} ${localeCode.startsWith('ar') ? 'أنشطة' : (localeCode.startsWith('de') ? 'Aktivitäten' : 'activities')}';
}
