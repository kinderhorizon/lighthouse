/// Isar startup helper.
///
/// One canonical place to open Isar with the active set of versioned
/// schemas. Called once at app startup (from main.dart) and once per
/// test that needs a real Isar instance against a tmp directory.
///
/// When V2 schemas land, [activeSchemas] grows; old V1 schemas stay in
/// the list until the parent confirms migration completion. See
/// ADR 0005.
library;

import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'bandit_state_v1.dart';
import 'raw_event_log_v1.dart';

/// The currently-active set of versioned collection schemas. Order does
/// not matter to Isar, but we keep oldest-version-first for human
/// readability.
final List<CollectionSchema<dynamic>> activeSchemas = [
  BanditStateV1Schema,
  RawEventLogV1Schema,
];

class IsarSetup {
  IsarSetup._();

  /// Subdirectory of the application-support dir that holds the Isar DB.
  ///
  /// PRIVACY-LOAD-BEARING (ADR 0002): on Android, getApplicationSupportDirectory
  /// maps to getFilesDir(), which Android Auto Backup and device-transfer
  /// include by DEFAULT. The DB holds RawEventLogV1, i.e. the child's actual
  /// button taps (communication content), so it must never leave the device.
  /// Isolating it in this named subdir lets the backup-exclusion XML exclude
  /// the whole directory by a stable path (rather than guessing Isar's internal
  /// filenames). The android/app/.../xml backup rules MUST exclude this exact
  /// name; backup_exclusion_test ties the two together so they cannot drift.
  static const String dbSubdir = 'lighthouse_db';

  /// Opens Isar against the application support directory, inside [dbSubdir]
  /// so the backup-exclusion rules can target it (see [dbSubdir]).
  static Future<Isar> openForApp() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$dbSubdir');
    await dir.create(recursive: true);
    return Isar.open(
      activeSchemas,
      directory: dir.path,
    );
  }

  /// Opens Isar against an explicit directory. Tests pass a tmp dir so
  /// each test gets isolated state. Also used by the asset-fixture
  /// loader when we materialize a frozen V1 snapshot into a real Isar
  /// instance for the migration-chain tests.
  static Future<Isar> openAt(Directory directory, {String? name}) async {
    return Isar.open(
      activeSchemas,
      directory: directory.path,
      name: name ?? Isar.defaultName,
    );
  }
}
