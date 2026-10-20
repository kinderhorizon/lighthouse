import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/backup/aac_backup_service.dart';
import 'package:lighthouse/services/cards/personal_card_store.dart';
import 'package:lighthouse/services/obf/open_board_format.dart';
import 'package:lighthouse/services/profile/profile_store.dart';
import 'package:lighthouse/services/schedule/daily_schedule_store.dart';
import 'package:lighthouse/services/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('OpenBoardFormat tests', () {
    test('isOBF identifies valid open-board documents', () {
      final obf = {
        'format': 'open-board-0.1',
        'id': 'test_obf',
        'name': 'Test OBF Board',
        'grid': {'rows': 2, 'columns': 2, 'order': []},
        'buttons': [],
      };

      expect(OpenBoardFormat.isOBF(obf), isTrue);
      expect(OpenBoardFormat.isOBF({'schema_version': '1.3'}), isFalse);
    });

    test('toAACBoard imports OBF format into functional AACBoard', () {
      final obfDoc = {
        'format': 'open-board-0.1',
        'id': 'colors_obf',
        'name': 'Colors Board',
        'grid': {
          'rows': 2,
          'columns': 2,
          'order': [
            ['btn_red', 'btn_blue'],
            ['btn_green', null],
          ],
        },
        'buttons': [
          {
            'id': 'btn_red',
            'label': 'Red',
            'vocalization': 'I want red',
            'image_url': 'assets/symbols/red.svg',
          },
          {
            'id': 'btn_blue',
            'label': 'Blue',
            'vocalization': 'Blue',
          },
          {
            'id': 'btn_green',
            'label': 'Green',
            'vocalization': 'Green',
          },
        ],
      };

      final board = OpenBoardFormat.toAACBoard(obfDoc);
      expect(board.boardId, equals('colors_obf'));
      expect(board.boardName, equals('Colors Board'));
      expect(board.gridDimensions.rows, equals(2));
      expect(board.gridDimensions.cols, equals(2));
      expect(board.buttons.length, equals(3));

      final red = board.buttons.firstWhere((b) => b.label == 'Red');
      expect(red.position, equals((row: 0, col: 0)));
      expect(red.voiceOut, equals('I want red'));
      expect(red.iconUri, equals('assets/symbols/red.svg'));

      final blue = board.buttons.firstWhere((b) => b.label == 'Blue');
      expect(blue.position, equals((row: 0, col: 1)));
    });

    test('toOBF converts AACBoard into standard open-board-0.1 JSON', () {
      final board = AACBoard(
        schemaVersion: '1.3',
        boardId: 'animals',
        boardName: 'Animals',
        gridDimensions: (rows: 1, cols: 2),
        colorKey: {'general': '#E0E0E0'},
        buttons: [
          const AACButton(
            id: 'btn_cat',
            label: 'Cat',
            labelByLocale: {},
            type: AACButtonType.word,
            position: (row: 0, col: 0),
            category: 'general',
            baseWeight: 1.0,
            iconUri: 'assets/cat.svg',
            voiceOut: 'Cat',
          ),
          const AACButton(
            id: 'btn_dog',
            label: 'Dog',
            labelByLocale: {},
            type: AACButtonType.word,
            position: (row: 0, col: 1),
            category: 'general',
            baseWeight: 1.0,
            iconUri: 'assets/dog.svg',
            voiceOut: 'Dog',
          ),
        ],
      );

      final obf = OpenBoardFormat.toOBF(board);
      expect(obf['format'], equals('open-board-0.1'));
      expect(obf['id'], equals('animals'));
      expect(obf['name'], equals('Animals'));
      expect(obf['grid']['rows'], equals(1));
      expect(obf['grid']['columns'], equals(2));
      final buttons = obf['buttons'] as List;
      expect(buttons.length, equals(2));
      expect(buttons.first['label'], equals('Cat'));
    });
  });

  group('AACBackupService tests', () {
    test('createBackupBundle captures profiles, active profile, and settings', () async {
      final profileStore = ProfileStore();
      final settingsRepo = SettingsRepository();

      await profileStore.createProfile(
        name: 'Sara',
        interfaceLocale: 'ar_dz',
        speechLocale: 'ar_dz',
        voiceRate: 0.85,
      );

      await settingsRepo.setLocaleOverride('ar_dz');
      await settingsRepo.setSpeechLocaleOverride('ar_dz');
      await settingsRepo.setAccessMethod(AccessMethod.switchSingle);
      await settingsRepo.setSwitchDwellMs(750);
      await settingsRepo.setVoiceRate(0.85);

      final service = AACBackupService(
        profileStore: profileStore,
        settingsRepo: settingsRepo,
      );

      final bundle = await service.createBackupBundle();
      expect(bundle['format'], equals(AACBackupService.currentBackupFormat));
      expect(bundle['profiles'], isA<List>());
      final profiles = bundle['profiles'] as List;
      expect(profiles.any((p) => p['name'] == 'Sara'), isTrue);

      final settings = bundle['settings'] as Map<String, dynamic>;
      expect(settings['locale_override'], equals('ar_dz'));
      expect(settings['access_method'], equals('switchSingle'));
      expect(settings['switch_dwell_ms'], equals(750));
      expect(settings['voice_rate'], equals(0.85));
    });

    test('restoreBackupBundle restores configuration into fresh stores', () async {
      final sourceProfileStore = ProfileStore();
      final sourceSettingsRepo = SettingsRepository();

      final p = await sourceProfileStore.createProfile(
        name: 'Yacine',
        interfaceLocale: 'ar',
        speechLocale: 'ar_dz',
      );
      await sourceProfileStore.setActiveProfileId(p.id);
      await sourceSettingsRepo.setAccessMethod(AccessMethod.switchDual);

      final service = AACBackupService(
        profileStore: sourceProfileStore,
        settingsRepo: sourceSettingsRepo,
      );

      final bundle = await service.createBackupBundle();

      // Clear SharedPreferences to simulate new device or fresh install
      SharedPreferences.setMockInitialValues({});

      final targetProfileStore = ProfileStore();
      final targetSettingsRepo = SettingsRepository();
      final targetService = AACBackupService(
        profileStore: targetProfileStore,
        settingsRepo: targetSettingsRepo,
      );

      final result = await targetService.restoreBackupBundle(bundle);
      expect(result.success, isTrue);
      expect(result.activeProfileId, equals(p.id));

      final restoredProfiles = await targetProfileStore.listProfiles();
      expect(restoredProfiles.any((p) => p.name == 'Yacine'), isTrue);

      final restoredActive = await targetProfileStore.getActiveProfile();
      expect(restoredActive.name, equals('Yacine'));

      final restoredSettings = await targetSettingsRepo.read();
      expect(restoredSettings.accessMethod, equals(AccessMethod.switchDual));
    });

    test('createBackupBundle and restoreBackupBundle round-trip personal cards and schedules', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_test_dir_');
      final profileStore = ProfileStore();
      final settingsRepo = SettingsRepository();
      final cardStore = PersonalCardStore(baseDirOverride: tempDir);
      final scheduleStore = DailyScheduleStore(baseDirOverride: tempDir);

      final p = await profileStore.getActiveProfile();
      await cardStore.saveCard(PersonalCard(
        id: 'card_grandma',
        profileId: p.id,
        name: 'Grandma',
        category: PersonalCardCategory.family,
        imageUri: 'assets/symbols/people/grandmother.png',
        labelsByLocale: const {'en': 'Grandma', 'ar': 'جدتي', 'ar_dz': 'جداتي', 'de': 'Oma'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await scheduleStore.saveSchedule(p.id, DailySchedule(
        id: 'sched_${p.id}',
        profileId: p.id,
        date: '2026-10-19',
        activities: const [
          ScheduleActivity(
            id: 'act_therapy',
            title: 'Speech Therapy',
            imageUri: 'assets/symbols/actions/talk.png',
            category: ScheduleActivityCategory.therapy,
          ),
        ],
      ));

      final service = AACBackupService(
        profileStore: profileStore,
        settingsRepo: settingsRepo,
        personalCardStore: cardStore,
        dailyScheduleStore: scheduleStore,
      );

      final bundle = await service.createBackupBundle();
      expect(bundle['personal_cards'], isA<List>());
      expect(bundle['daily_schedules'], isA<Map>());

      final targetTempDir = Directory.systemTemp.createTempSync('backup_target_dir_');
      final targetCardStore = PersonalCardStore(baseDirOverride: targetTempDir);
      final targetScheduleStore = DailyScheduleStore(baseDirOverride: targetTempDir);
      final targetService = AACBackupService(
        profileStore: ProfileStore(),
        settingsRepo: SettingsRepository(),
        personalCardStore: targetCardStore,
        dailyScheduleStore: targetScheduleStore,
      );

      final result = await targetService.restoreBackupBundle(bundle);
      expect(result.success, isTrue);
      expect(result.cardsRestored, equals(4));
      expect(result.schedulesRestored, equals(1));

      final restoredCards = await targetCardStore.loadCards(p.id);
      expect(restoredCards.any((c) => c.name == 'Grandma'), isTrue);

      final restoredSchedule = await targetScheduleStore.loadSchedule(p.id, '2026-10-19');
      expect(restoredSchedule.activities.any((a) => a.title == 'Speech Therapy'), isTrue);
    });

    test('Rejects invalid backup format safely', () async {
      final service = AACBackupService(
        profileStore: ProfileStore(),
        settingsRepo: SettingsRepository(),
      );

      final result = await service.restoreBackupBundle({
        'format': 'unknown-format-9.9',
      });

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Unsupported backup format'));
    });

    test('restoreFromFile handles non-existent, corrupt, and non-map JSON files cleanly', () async {
      final tempDir = Directory.systemTemp.createTempSync('backup_corrupt_test_');
      final service = AACBackupService(
        profileStore: ProfileStore(),
        settingsRepo: SettingsRepository(),
      );

      // 1. Non-existent file
      final nonExistent = File('${tempDir.path}/missing.json');
      final missingResult = await service.restoreFromFile(nonExistent);
      expect(missingResult.success, isFalse);
      expect(missingResult.errorMessage, contains('does not exist'));

      // 2. Syntax-corrupted/truncated JSON
      final corruptFile = File('${tempDir.path}/corrupt.json');
      await corruptFile.writeAsString('{"format": "nuritalk-aac-backup-1.0", "profiles": [ { "id": "p1"'); // Unclosed JSON
      final corruptResult = await service.restoreFromFile(corruptFile);
      expect(corruptResult.success, isFalse);
      expect(corruptResult.errorMessage, contains('Invalid JSON format'));

      // 3. Valid JSON but not a Map root (e.g. array)
      final arrayFile = File('${tempDir.path}/array.json');
      await arrayFile.writeAsString('[1, 2, 3]');
      final arrayResult = await service.restoreFromFile(arrayFile);
      expect(arrayResult.success, isFalse);
      expect(arrayResult.errorMessage, contains('Malformed backup JSON file'));
    });

    test('Accepts both legacy lighthouse and modern nuritalk backup schema versions', () async {
      final service = AACBackupService(
        profileStore: ProfileStore(),
        settingsRepo: SettingsRepository(),
      );

      // Legacy format
      final legacyResult = await service.restoreBackupBundle({
        'format': 'lighthouse-aac-backup-1.0',
        'profiles': [
          {'id': 'legacy_user', 'name': 'Legacy User'}
        ],
      });
      expect(legacyResult.success, isTrue);

      // Modern format
      final modernResult = await service.restoreBackupBundle({
        'format': 'nuritalk-aac-backup-1.0',
        'profiles': [
          {'id': 'modern_user', 'name': 'Modern User'}
        ],
      });
      expect(modernResult.success, isTrue);

      // Minor future version within 1.x
      final futureResult = await service.restoreBackupBundle({
        'format': 'nuritalk-aac-backup-1.2',
        'profiles': [
          {'id': 'future_user', 'name': 'Future User'}
        ],
      });
      expect(futureResult.success, isTrue);

      // Unversioned legacy bundle with profiles
      final unversionedResult = await service.restoreBackupBundle({
        'profiles': [
          {'id': 'unversioned_user', 'name': 'Unversioned User'}
        ],
      });
      expect(unversionedResult.success, isTrue);
    });

    test('Category normalization safely maps missing, empty, or unknown categories', () {
      // PersonalCardCategory normalization
      expect(PersonalCardCategory.normalize(null), equals(PersonalCardCategory.custom));
      expect(PersonalCardCategory.normalize(''), equals(PersonalCardCategory.custom));
      expect(PersonalCardCategory.normalize('unknown_category'), equals(PersonalCardCategory.custom));
      expect(PersonalCardCategory.normalize('FAMILY'), equals(PersonalCardCategory.family));
      expect(PersonalCardCategory.normalize('food'), equals(PersonalCardCategory.food));

      // ScheduleActivityCategory normalization
      expect(ScheduleActivityCategory.normalize(null), equals(ScheduleActivityCategory.routine));
      expect(ScheduleActivityCategory.normalize(''), equals(ScheduleActivityCategory.routine));
      expect(ScheduleActivityCategory.normalize('unknown_activity_type'), equals(ScheduleActivityCategory.custom));
      expect(ScheduleActivityCategory.normalize('THERAPY'), equals(ScheduleActivityCategory.therapy));
      expect(ScheduleActivityCategory.normalize('hygiene'), equals(ScheduleActivityCategory.hygiene));
    });

    test('Partial payload recovery: corrupt items in lists are skipped without failing valid items', () async {
      final tempDir = Directory.systemTemp.createTempSync('partial_payload_test_');
      final cardStore = PersonalCardStore(baseDirOverride: tempDir);
      final scheduleStore = DailyScheduleStore(baseDirOverride: tempDir);

      final service = AACBackupService(
        profileStore: ProfileStore(),
        settingsRepo: SettingsRepository(),
        personalCardStore: cardStore,
        dailyScheduleStore: scheduleStore,
      );

      final bundle = {
        'format': 'nuritalk-aac-backup-1.0',
        'active_profile_id': 'partial_prof',
        'profiles': [
          {'id': 'partial_prof', 'name': 'Valid Profile'},
          'completely_invalid_profile_string', // Corrupt profile entry
        ],
        'personal_cards': [
          {
            'id': 'valid_card',
            'profile_id': 'partial_prof',
            'name': 'Valid Card',
            'category': 'family',
          },
          'corrupted_card_entry', // Corrupt card entry
        ],
        'daily_schedules': {
          'id': 'partial_sched',
          'profile_id': 'partial_prof',
          'date': '2026-10-20',
          'activities': [
            {
              'id': 'valid_act',
              'title': 'Morning Walk',
              'category': 'routine',
            },
            'corrupted_activity', // Corrupt activity in schedule
          ],
        },
      };

      final result = await service.restoreBackupBundle(bundle);
      expect(result.success, isTrue);
      expect(result.profilesRestored, equals(1));
      expect(result.cardsRestored, equals(1));
      expect(result.schedulesRestored, equals(1));

      final restoredCards = await cardStore.loadCards('partial_prof');
      expect(restoredCards.any((c) => c.id == 'valid_card'), isTrue);

      final restoredSchedule = await scheduleStore.loadSchedule('partial_prof', '2026-10-20');
      expect(restoredSchedule.activities.length, equals(1));
      expect(restoredSchedule.activities.first.title, equals('Morning Walk'));
    });

    test('Protects against oversized image attachments', () async {
      final tempDir = Directory.systemTemp.createTempSync('oversized_img_test_');
      final cardStore = PersonalCardStore(baseDirOverride: tempDir);

      // 1. PersonalCardStore.saveCardImage throws on >5MB bytes
      final oversizedBytes = Uint8List(PersonalCardStore.maxImageByteSize + 1024);
      expect(
        () => cardStore.saveCardImage(
          profileId: 'test_prof',
          cardId: 'oversized_card',
          bytes: oversizedBytes,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // 2. Deserializing PersonalCard with massive base64 URI sanitizes to default symbol
      final oversizedDataUri = 'data:image/jpeg;base64,${'A' * (5 * 1024 * 1024 + 100)}';
      final card = PersonalCard.fromJson({
        'id': 'card_with_huge_photo',
        'name': 'Oversized Photo Card',
        'image_uri': oversizedDataUri,
      });
      expect(card.imageUri, equals('assets/symbols/things/star.png'));
    });

    test('Restores daily schedules formatted as map of dates', () async {
      final tempDir = Directory.systemTemp.createTempSync('multi_sched_test_');
      final scheduleStore = DailyScheduleStore(baseDirOverride: tempDir);

      final service = AACBackupService(
        profileStore: ProfileStore(),
        settingsRepo: SettingsRepository(),
        dailyScheduleStore: scheduleStore,
      );

      final bundle = {
        'format': 'nuritalk-aac-backup-1.0',
        'active_profile_id': 'multi_sched_prof',
        'profiles': [
          {'id': 'multi_sched_prof', 'name': 'Multi Schedule Child'},
        ],
        'daily_schedules': {
          '2026-10-21': {
            'id': 'sched_oct21',
            'profile_id': 'multi_sched_prof',
            'date': '2026-10-21',
            'activities': [
              {'id': 'act_21', 'title': 'Dentist', 'category': 'routine'}
            ],
          },
          '2026-10-22': {
            'id': 'sched_oct22',
            'profile_id': 'multi_sched_prof',
            'date': '2026-10-22',
            'activities': [
              {'id': 'act_22', 'title': 'Swimming', 'category': 'leisure'}
            ],
          },
        },
      };

      final result = await service.restoreBackupBundle(bundle);
      expect(result.success, isTrue);
      expect(result.schedulesRestored, equals(2));

      final sched21 = await scheduleStore.loadSchedule('multi_sched_prof', '2026-10-21');
      expect(sched21.activities.first.title, equals('Dentist'));

      final sched22 = await scheduleStore.loadSchedule('multi_sched_prof', '2026-10-22');
      expect(sched22.activities.first.title, equals('Swimming'));
    });

    test('Self-healing disk persistence: recovers gracefully from corrupted files on disk', () async {
      final tempDir = Directory.systemTemp.createTempSync('self_heal_test_');
      final scheduleStore = DailyScheduleStore(baseDirOverride: tempDir);
      final cardStore = PersonalCardStore(baseDirOverride: tempDir);
      const profileId = 'heal_prof';

      // 1. Corrupt daily_schedules.json on disk
      final schedDir = Directory('${tempDir.path}/profiles/$profileId');
      schedDir.createSync(recursive: true);
      final schedFile = File('${schedDir.path}/daily_schedules.json');
      schedFile.writeAsStringSync('{{{ THIS IS NOT JSON AND TRUNCATED ...');

      // loadSchedule should not throw, should back up corrupted file, and return starter schedule
      final recoveredSchedule = await scheduleStore.loadSchedule(profileId, '2026-10-20');
      expect(recoveredSchedule.activities, isNotEmpty);
      expect(recoveredSchedule.profileId, equals(profileId));

      final archivedSchedFiles = schedDir.listSync().where((f) => f.path.contains('.corrupt_')).toList();
      expect(archivedSchedFiles, isNotEmpty);

      // 2. Corrupt personal_cards.json on disk
      final cardFile = File('${schedDir.path}/personal_cards.json');
      cardFile.writeAsStringSync('CORRUPT_BYTES_XYZ_9999');

      // loadCards should not throw, should back up corrupted file, and return starter cards
      final recoveredCards = await cardStore.loadCards(profileId);
      expect(recoveredCards, isNotEmpty);
      expect(recoveredCards.any((c) => c.name == 'Mother'), isTrue);

      final archivedCardFiles = schedDir.listSync().where((f) => f.path.contains('personal_cards.json.corrupt_')).toList();
      expect(archivedCardFiles, isNotEmpty);
    });
  });
}
