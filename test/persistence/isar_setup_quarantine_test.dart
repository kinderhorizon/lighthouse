/// Host-runnable tests for the conservative corrupt-DB quarantine (ADR 0005
/// amendment 2026-06-10, review item 11).
///
/// [IsarSetup.quarantineCorruptDb] is pure dart:io (no Isar native library), so
/// it runs under `flutter test` on the host, unlike the real-Isar open/prune
/// paths which live in integration_test/persistence_test.dart. These tests pin
/// the data-DESTRUCTION behavior of the recovery path: it must rename the
/// corrupt DB aside (preserving the child's tap history) rather than delete it,
/// and must not let repeated corruption pile up copies of communication content.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/persistence/isar_setup.dart';

void main() {
  late Directory base;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('isar_quarantine_test_');
  });

  tearDown(() async {
    if (base.existsSync()) await base.delete(recursive: true);
  });

  Directory liveDir() => Directory('${base.path}/${IsarSetup.dbSubdir}');
  Directory quarantineDir() =>
      Directory('${base.path}/${IsarSetup.corruptDbSubdir}');

  test('renames the live DB aside instead of deleting it (data preserved)',
      () async {
    final live = liveDir()..createSync(recursive: true);
    File('${live.path}/marker.dat').writeAsStringSync('child taps');

    await IsarSetup.quarantineCorruptDb(base);

    expect(live.existsSync(), isFalse,
        reason: 'the corrupt live dir is moved out of the way for a fresh open');
    expect(quarantineDir().existsSync(), isTrue);
    expect(
      File('${quarantineDir().path}/marker.dat').readAsStringSync(),
      'child taps',
      reason: 'quarantine PRESERVES the data (ADR 0005); it must not delete it, '
          'so a recoverable fault like a full disk does not destroy tap history',
    );
  });

  test('replaces a prior quarantine rather than piling up copies', () async {
    quarantineDir().createSync(recursive: true);
    File('${quarantineDir().path}/old.dat').writeAsStringSync('stale');
    final live = liveDir()..createSync(recursive: true);
    File('${live.path}/current.dat').writeAsStringSync('current');

    await IsarSetup.quarantineCorruptDb(base);

    expect(File('${quarantineDir().path}/current.dat').existsSync(), isTrue,
        reason: 'the latest corrupt DB becomes the quarantine');
    expect(File('${quarantineDir().path}/old.dat').existsSync(), isFalse,
        reason: 'only the latest quarantine is kept; each holds communication '
            'content, so a repeatedly-corrupting DB must not accumulate copies');
  });

  test('is a no-op when there is no live DB to quarantine', () async {
    await IsarSetup.quarantineCorruptDb(base);
    expect(quarantineDir().existsSync(), isFalse);
    expect(liveDir().existsSync(), isFalse);
  });
}
