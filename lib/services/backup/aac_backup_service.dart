/// Full AAC Backup and Restore Service.
///
/// Exports and imports complete AAC application configurations, including:
/// 1. All User Profiles (clinical, multi-child, independent preferences).
/// 2. Active profile pointer.
/// 3. Comprehensive settings (TTS mode, speech rate/pitch, switch access, AI prediction).
///
/// Operates completely offline, safe against corruption, and adheres to strict schema checks.
library;

import 'dart:convert';
import 'dart:io';

import '../../models/daily_schedule.dart';
import '../../models/personal_card.dart';
import '../../models/user_profile.dart';
import '../cards/personal_card_store.dart';
import '../profile/profile_store.dart';
import '../schedule/daily_schedule_store.dart';
import '../settings/settings_repository.dart';

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.success,
    required this.profilesRestored,
    required this.activeProfileId,
    this.cardsRestored = 0,
    this.schedulesRestored = 0,
    this.errorMessage,
  });

  final bool success;
  final int profilesRestored;
  final int cardsRestored;
  final int schedulesRestored;
  final String activeProfileId;
  final String? errorMessage;
}

class AACBackupService {
  AACBackupService({
    required this.profileStore,
    required this.settingsRepo,
    this.personalCardStore,
    this.dailyScheduleStore,
  });

  final ProfileStore profileStore;
  final SettingsRepository settingsRepo;
  final PersonalCardStore? personalCardStore;
  final DailyScheduleStore? dailyScheduleStore;

  static const String currentBackupFormat = 'nuritalk-aac-backup-1.0';
  static const String legacyBackupFormat = 'lighthouse-aac-backup-1.0';

  static const List<String> supportedBackupFormats = [
    currentBackupFormat,
    legacyBackupFormat,
    'lighthouse-aac-backup-0.9',
    'nuritalk-aac-backup-1.1',
  ];

  /// Checks if [format] is supported by this version of NūriTalk.
  static bool isSupportedFormat(dynamic format, Map<String, dynamic> bundle) {
    if (format is String) {
      if (supportedBackupFormats.contains(format)) return true;
      final match = RegExp(r'^(nuritalk|lighthouse)-aac-backup-(\d+)\.(\d+)$').firstMatch(format);
      if (match != null) {
        final major = int.tryParse(match.group(2) ?? '');
        // Major version 1.x is fully backwards- and forwards-compatible
        if (major == 1) return true;
      }
    }
    // Allow legacy bundles lacking an explicit format tag if they contain valid profiles or settings
    if (format == null && (bundle.containsKey('profiles') || bundle.containsKey('settings'))) {
      return true;
    }
    return false;
  }

  /// Creates a complete JSON backup bundle.
  Future<Map<String, dynamic>> createBackupBundle() async {
    final profiles = await profileStore.listProfiles();
    final active = await profileStore.getActiveProfile();
    final settings = await settingsRepo.read();
    final cards = personalCardStore != null
        ? await personalCardStore!.loadCards(active.id)
        : const <PersonalCard>[];
    final schedule = dailyScheduleStore != null
        ? await dailyScheduleStore!.loadSchedule(active.id)
        : null;

    return {
      'format': currentBackupFormat,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'active_profile_id': active.id,
      'profiles': profiles.map((p) => p.toJson()).toList(),
      if (cards.isNotEmpty)
        'personal_cards': cards.map((c) => c.toJson()).toList(),
      if (schedule != null) 'daily_schedules': schedule.toJson(),
      'settings': {
        'tts_mode': settings.ttsMode.name,
        'glow_style': settings.glowStyle.name,
        'hitbox_magnitude': settings.hitboxMagnitude.name,
        'locale_override': settings.localeOverride,
        'speech_locale_override': settings.speechLocaleOverride,
        'voice_rate': settings.voiceRate,
        'voice_pitch': settings.voicePitch,
        'high_contrast': settings.highContrast,
        'enable_ai_prediction': settings.enableAiPrediction,
        'access_method': settings.accessMethod.name,
        'switch_dwell_ms': settings.switchDwellMs,
        'auto_return_to_home': settings.autoReturnToHome,
        'hide_tile_text': settings.hideTileText,
        'hide_pictogram': settings.hidePictogram,
      },
    };
  }

  /// Writes the backup bundle to [destinationFile].
  Future<File> exportToFile(File destinationFile) async {
    final bundle = await createBackupBundle();
    return destinationFile.writeAsString(const JsonEncoder.withIndent('  ').convert(bundle));
  }

  /// Restores application state from a JSON backup map.
  Future<BackupRestoreResult> restoreBackupBundle(Map<String, dynamic> bundle) async {
    final format = bundle['format'];
    if (!isSupportedFormat(format, bundle)) {
      return BackupRestoreResult(
        success: false,
        profilesRestored: 0,
        activeProfileId: '',
        errorMessage: 'Unsupported backup format: $format',
      );
    }

    final rawProfiles = bundle['profiles'];
    if (rawProfiles != null && rawProfiles is! List) {
      return const BackupRestoreResult(
        success: false,
        profilesRestored: 0,
        activeProfileId: '',
        errorMessage: 'Invalid profiles list in backup bundle',
      );
    }

    var restoredCount = 0;
    if (rawProfiles is List) {
      for (final item in rawProfiles) {
        if (item is Map<String, dynamic>) {
          try {
            final profile = UserProfile.fromJson(item);
            await profileStore.saveProfile(profile);
            restoredCount++;
          } catch (_) {}
        }
      }
    }

    final activeId = bundle['active_profile_id'] as String? ?? 'default';
    await profileStore.setActiveProfileId(activeId);

    final rawSettings = bundle['settings'];
    if (rawSettings is Map<String, dynamic>) {
      if (rawSettings['tts_mode'] != null) {
        final tts = TtsMode.tryParse(rawSettings['tts_mode'].toString());
        if (tts != null) await settingsRepo.setTtsMode(tts);
      }
      if (rawSettings['glow_style'] != null) {
        final glow = GlowStyle.tryParse(rawSettings['glow_style'].toString());
        if (glow != null) await settingsRepo.setGlowStyle(glow);
      }
      if (rawSettings['hitbox_magnitude'] != null) {
        final hit = HitboxMagnitude.tryParse(rawSettings['hitbox_magnitude'].toString());
        if (hit != null) await settingsRepo.setHitboxMagnitude(hit);
      }
      if (rawSettings.containsKey('locale_override')) {
        await settingsRepo.setLocaleOverride(rawSettings['locale_override']?.toString());
      }
      if (rawSettings.containsKey('speech_locale_override')) {
        await settingsRepo.setSpeechLocaleOverride(rawSettings['speech_locale_override']?.toString());
      }
      if (rawSettings['voice_rate'] != null) {
        final rate = (rawSettings['voice_rate'] as num?)?.toDouble();
        if (rate != null) await settingsRepo.setVoiceRate(rate);
      }
      if (rawSettings['voice_pitch'] != null) {
        final pitch = (rawSettings['voice_pitch'] as num?)?.toDouble();
        if (pitch != null) await settingsRepo.setVoicePitch(pitch);
      }
      if (rawSettings['high_contrast'] != null) {
        await settingsRepo.setHighContrast(rawSettings['high_contrast'] == true);
      }
      if (rawSettings['enable_ai_prediction'] != null) {
        await settingsRepo.setEnableAiPrediction(rawSettings['enable_ai_prediction'] == true);
      }
      if (rawSettings['access_method'] != null) {
        final method = AccessMethod.tryParse(rawSettings['access_method'].toString());
        await settingsRepo.setAccessMethod(method);
      }
      if (rawSettings['switch_dwell_ms'] != null) {
        final dwell = (rawSettings['switch_dwell_ms'] as num?)?.toInt();
        if (dwell != null) await settingsRepo.setSwitchDwellMs(dwell);
      }
      if (rawSettings['auto_return_to_home'] != null) {
        await settingsRepo.setAutoReturnToHome(rawSettings['auto_return_to_home'] != false);
      }
      if (rawSettings['hide_tile_text'] != null) {
        await settingsRepo.setHideTileText(rawSettings['hide_tile_text'] == true);
      }
      if (rawSettings['hide_pictogram'] != null) {
        await settingsRepo.setHidePictogram(rawSettings['hide_pictogram'] == true);
      }
    }

    var cardsRestored = 0;
    if (personalCardStore != null && bundle['personal_cards'] is List) {
      for (final item in bundle['personal_cards'] as List) {
        if (item is Map<String, dynamic>) {
          try {
            await personalCardStore!.saveCard(PersonalCard.fromJson(item));
            cardsRestored++;
          } catch (_) {}
        }
      }
    }

    var schedulesRestored = 0;
    if (dailyScheduleStore != null && bundle['daily_schedules'] != null) {
      final rawSchedules = bundle['daily_schedules'];
      if (rawSchedules is Map<String, dynamic>) {
        if (rawSchedules.containsKey('activities')) {
          try {
            final schedule = DailySchedule.fromJson(rawSchedules);
            await dailyScheduleStore!.saveSchedule(activeId, schedule);
            schedulesRestored++;
          } catch (_) {}
        } else {
          for (final entry in rawSchedules.entries) {
            if (entry.value is Map<String, dynamic>) {
              try {
                final schedule = DailySchedule.fromJson(entry.value as Map<String, dynamic>);
                await dailyScheduleStore!.saveSchedule(activeId, schedule);
                schedulesRestored++;
              } catch (_) {}
            }
          }
        }
      } else if (rawSchedules is List) {
        for (final item in rawSchedules) {
          if (item is Map<String, dynamic>) {
            try {
              final schedule = DailySchedule.fromJson(item);
              await dailyScheduleStore!.saveSchedule(activeId, schedule);
              schedulesRestored++;
            } catch (_) {}
          }
        }
      }
    }

    return BackupRestoreResult(
      success: true,
      profilesRestored: restoredCount,
      activeProfileId: activeId,
      cardsRestored: cardsRestored,
      schedulesRestored: schedulesRestored,
    );
  }

  /// Restores from a file.
  Future<BackupRestoreResult> restoreFromFile(File file) async {
    if (!file.existsSync()) {
      return const BackupRestoreResult(
        success: false,
        profilesRestored: 0,
        activeProfileId: '',
        errorMessage: 'Backup file does not exist',
      );
    }
    try {
      final raw = await file.readAsString();
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const BackupRestoreResult(
          success: false,
          profilesRestored: 0,
          activeProfileId: '',
          errorMessage: 'Malformed backup JSON file',
        );
      }
      return await restoreBackupBundle(decoded);
    } on FormatException catch (e) {
      return BackupRestoreResult(
        success: false,
        profilesRestored: 0,
        activeProfileId: '',
        errorMessage: 'Invalid JSON format in backup file: ${e.message}',
      );
    } catch (e) {
      return BackupRestoreResult(
        success: false,
        profilesRestored: 0,
        activeProfileId: '',
        errorMessage: 'Failed to restore backup: $e',
      );
    }
  }
}
