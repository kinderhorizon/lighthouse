/// Backup-exclusion guard (ADR 0002, privacy-load-bearing).
///
/// The entire offline-privacy promise rests on the child's data never leaving
/// the device. On Android the Isar DB lives in getApplicationSupportDirectory()
/// = getFilesDir(), which Auto Backup and device-transfer INCLUDE by default,
/// so the DB (RawEventLogV1 = the child's button taps) must be explicitly
/// excluded. These failures would be silent and invisible until a backup audit,
/// so we gate CI on them:
///   1. Both backup XML files exclude the Isar DB subdir (IsarSetup.dbSubdir),
///      tied to the code constant so a rename of one without the other fails.
///   2. data_extraction_rules excludes it in BOTH cloud-backup and
///      device-transfer (cloud and local-migration are separate channels).
///   3. No `domain="database"` entry re-enters (invalid for subdir paths, fails
///      release lint, and is not where our DB lives anyway).
///   4. The crash_logs excludes are not regressed.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/persistence/isar_setup.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  const dataRules =
      'android/app/src/main/res/xml/data_extraction_rules.xml';
  const fullBackup =
      'android/app/src/main/res/xml/full_backup_content.xml';

  String read(String p) => File(p).readAsStringSync();

  String fileExclude(String path) => '<exclude domain="file" path="$path" />';

  // Every privacy-bearing path under getFilesDir() that must NOT be backed up,
  // each tied to the code constant that names it on disk so a rename of one
  // without the other fails CI. The DB holds the child's taps; the rest is
  // parent-authored content / customization (ADR 0002, 0012/0013/0014/0017).
  final excludedPaths = <String>{
    '${IsarSetup.dbSubdir}/',
    // The quarantine the live DB is renamed aside to on an unrecoverable open
    // (item 5). It holds the same RawEventLogV1 communication content, so it
    // MUST be excluded exactly like the live DB or the recovery itself leaks.
    '${IsarSetup.corruptDbSubdir}/',
    CustomButtonStore.fileName,
    '${CustomButtonStore.imagesSubdir}/',
    FavouritesStore.fileName,
    BoardLayoutStore.fileName,
    HiddenTilesStore.fileName,
    IconOverrideStore.fileName,
    '${IconOverrideStore.imagesSubdir}/',
    CustomVoiceStore.fileName,
    '${CustomVoiceStore.clipsSubdir}/',
    '${BoardRegistry.importSubdirName}/',
    '${ContentOverlayStore.subdirName}/',
  };

  // The atomic-write temp siblings (<store>.json.tmp, atomic_file.dart) live at
  // the same files-dir root and hold the same communication content mid-write; a
  // hard kill between write and rename strands one, which would then sync to the
  // parent's Google account on every backup (item 6). Every excluded root JSON
  // store must also exclude its .tmp sibling.
  final tmpPaths = <String>{
    for (final p in excludedPaths)
      if (p.endsWith('.json')) '$p.tmp',
  };

  final allExcluded = <String>{...excludedPaths, ...tmpPaths};

  test('every privacy-bearing path is excluded in both backup XML files', () {
    final data = read(dataRules);
    final full = read(fullBackup);
    for (final p in allExcluded) {
      expect(data, contains(fileExclude(p)),
          reason: 'data_extraction_rules must exclude "$p" or that content is '
              'backed up to the parent Google account');
      expect(full, contains(fileExclude(p)),
          reason: 'full_backup_content (legacy Auto Backup) must exclude "$p"');
    }
  });

  test('every privacy-bearing path is excluded in BOTH cloud-backup and '
      'device-transfer', () {
    final xml = read(dataRules);
    // Cloud backup and local device-to-device transfer are independent channels.
    final cloud = RegExp(r'<cloud-backup>(.*?)</cloud-backup>', dotAll: true)
        .firstMatch(xml)
        ?.group(1);
    final transfer =
        RegExp(r'<device-transfer>(.*?)</device-transfer>', dotAll: true)
            .firstMatch(xml)
            ?.group(1);
    expect(cloud, isNotNull);
    expect(transfer, isNotNull);
    for (final p in allExcluded) {
      expect(cloud, contains(fileExclude(p)),
          reason: '"$p" missing in <cloud-backup>');
      expect(transfer, contains(fileExclude(p)),
          reason: '"$p" missing in <device-transfer>');
    }
  });

  test('no "database" domain rule re-enters (invalid + privacy)', () {
    for (final p in [dataRules, fullBackup]) {
      expect(read(p), isNot(contains('domain="database"')),
          reason: '$p must not use the database domain: a path entry there is '
              'invalid (release lint) and the Isar DB is not in getDatabasePath');
    }
  });

  test('crash_logs excludes are not regressed', () {
    for (final p in [dataRules, fullBackup]) {
      expect(read(p), contains('path="crash_logs/"'),
          reason: '$p must keep the crash_logs defense-in-depth excludes');
    }
  });
}
