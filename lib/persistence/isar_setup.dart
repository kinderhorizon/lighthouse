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

  /// Subdirectory the live DB is QUARANTINED to (renamed aside) when an open
  /// fails unrecoverably, instead of being deleted outright.
  ///
  /// RawEventLogV1 is the child's tap history and ADR 0005's recovery source of
  /// truth, so a recoverable cause (a full disk, a transient lock) must not cost
  /// that data: rename-aside preserves it for inspection or hand-recovery while a
  /// fresh DB lets the child's board come back. This MUST be backup-excluded
  /// exactly like [dbSubdir] because it holds the same communication content;
  /// both backup XMLs list it and backup_exclusion_test ties them together.
  static const String corruptDbSubdir = 'lighthouse_db_corrupt';

  /// Max DB size, i.e. the size of the memory-mapped region Isar reserves.
  ///
  /// Passed explicitly because the isar_community default (512 MiB) reserves a
  /// virtual mapping too large to place reliably inside a 32-bit process
  /// (armeabi-v7a is served), which itself surfaces as an open failure and used
  /// to trigger the destructive reset below. Our data is bounded (the raw event
  /// log is capped at 20k rows in BanditRepository, plus small bandit state), so
  /// 128 MiB is generous headroom while keeping the 32-bit reservation modest.
  static const int maxDbSizeMiB = 128;

  static Future<Isar> _open(Directory dir) => Isar.open(
        activeSchemas,
        directory: dir.path,
        maxSizeMiB: maxDbSizeMiB,
      );

  /// Opens Isar against the application support directory, inside [dbSubdir]
  /// so the backup-exclusion rules can target it (see [dbSubdir]).
  ///
  /// Recovery on an open failure is deliberately CONSERVATIVE (ADR 0005
  /// amendment 2026-06-10): retry once (a transient lock or a not-yet-released
  /// instance from a failed prior open can clear), then if it still fails
  /// QUARANTINE the directory (rename aside, never delete) and open fresh, so an
  /// unbounded brick-on-every-launch never happens AND a recoverable fault
  /// (full disk, 32-bit mmap) does not destroy the child's tap history.
  /// [onCorruptDbReset] is invoked with the original failure so the caller can
  /// set the bandit-corruption diagnostic flag and note it in the crash log.
  static Future<Isar> openForApp({
    void Function(Object error, StackTrace stack)? onCorruptDbReset,
  }) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$dbSubdir');
    await dir.create(recursive: true);
    try {
      return await _open(dir);
    } catch (error, stack) {
      // Startup CANNOT proceed without Isar, and this open is the one unguarded
      // failure point that would brick the app on EVERY launch: the same file is
      // reopened each time, so the child sees the splash forever (no board, no
      // voice). Field causes for isar_community 3.x (mdbx): corruption after a
      // power loss or force-kill mid-write; a full disk; a 32-bit mmap placement
      // failure; an unrecoverable schema state.
      onCorruptDbReset?.call(error, stack);

      // Retry ONCE before touching the data. A transient fault (a momentary
      // lock, an instance left registered by a failed prior open) can clear on a
      // second attempt, so we never quarantine a DB we did not have to.
      await _closeExisting();
      try {
        return await _open(dir);
      } catch (_) {
        // Still failing: quarantine (rename aside), not delete. The quarantine
        // name is itself backup-excluded, so the privacy invariant (ADR 0002) is
        // preserved while the data is kept. Then open a fresh DB so the board
        // returns; glow learning resets, which is reconstructible.
        await quarantineCorruptDb(base);
        await dir.create(recursive: true);
        return await _open(dir);
      }
    }
  }

  /// Closes any Isar instance left registered under the default name, best
  /// effort. A failed [Isar.open] can leave a half-registered instance that
  /// makes the retry throw "instance already open"; clearing it first avoids
  /// that latent double-open trap.
  static Future<void> _closeExisting() async {
    try {
      await Isar.getInstance()?.close();
    } catch (_) {/* best-effort */}
  }

  /// Renames the live DB directory under [base] aside to [corruptDbSubdir],
  /// replacing any prior quarantine (a repeatedly-corrupting DB must not pile up
  /// copies, each of which holds communication content). Falls back to a delete
  /// only if the rename itself fails, since preserving data must never come at
  /// the cost of bricking the child's board. Exposed for the recovery test.
  static Future<void> quarantineCorruptDb(Directory base) async {
    final dir = Directory('${base.path}/$dbSubdir');
    final quarantine = Directory('${base.path}/$corruptDbSubdir');
    try {
      if (await quarantine.exists()) {
        await quarantine.delete(recursive: true);
      }
      if (await dir.exists()) {
        await dir.rename(quarantine.path);
      }
    } catch (_) {
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {/* nothing more we can safely do */}
    }
  }

  /// Opens Isar against an explicit directory. Tests pass a tmp dir so
  /// each test gets isolated state. Also used by the asset-fixture
  /// loader when we materialize a frozen V1 snapshot into a real Isar
  /// instance for the migration-chain tests. Uses the same [maxDbSizeMiB] as
  /// the app open so tests exercise the production configuration.
  static Future<Isar> openAt(Directory directory, {String? name}) async {
    return Isar.open(
      activeSchemas,
      directory: directory.path,
      name: name ?? Isar.defaultName,
      maxSizeMiB: maxDbSizeMiB,
    );
  }
}
