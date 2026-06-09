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
  ///
  /// If the open fails, the corrupt DB is discarded and a fresh one is opened
  /// (see the catch block for why this is safe and why it deletes rather than
  /// renames). [onCorruptDbReset] is invoked with the original failure so the
  /// caller can note it in the crash log; recovery proceeds regardless.
  static Future<Isar> openForApp({
    void Function(Object error, StackTrace stack)? onCorruptDbReset,
  }) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$dbSubdir');
    await dir.create(recursive: true);
    try {
      return await Isar.open(
        activeSchemas,
        directory: dir.path,
      );
    } catch (error, stack) {
      // Startup CANNOT proceed without Isar, and this open is the one
      // unguarded failure point that would brick the app on EVERY launch: the
      // same corrupt file is reopened each time, so the child sees the splash
      // forever (no board, no voice). Field causes for isar_community 3.x
      // (mdbx): corruption after a power loss or force-kill mid-write; an
      // unrecoverable schema state would do the same.
      //
      // Recovery is safe because of what this DB does and does not hold. It
      // holds ONLY reconstructible learning data: BanditStateV1 (the glow
      // predictions) and RawEventLogV1 (the tap log). Every piece of
      // parent-authored content the child depends on (custom buttons,
      // recordings, favourites, layouts) lives in separate JSON stores at the
      // app-support root, OUTSIDE [dbSubdir]. So discarding this directory
      // resets glow learning and nothing else: the child keeps their voice.
      //
      // We DELETE rather than rename-aside on purpose. The backup-exclusion
      // rules (ADR 0002) exclude this directory BY NAME because RawEventLogV1
      // is the child's communication content and must never leave the device;
      // a renamed copy (e.g. lighthouse_db.corrupt) would fall outside that
      // exclusion and could be swept into Android Auto Backup or a device
      // transfer. Deleting keeps the privacy invariant intact.
      onCorruptDbReset?.call(error, stack);
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {
        // If the wipe itself fails there is nothing more we can safely do;
        // fall through and let the reopen throw, which is no worse than the
        // original unguarded behavior.
      }
      await dir.create(recursive: true);
      return await Isar.open(
        activeSchemas,
        directory: dir.path,
      );
    }
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
