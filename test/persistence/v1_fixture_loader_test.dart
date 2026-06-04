/// Pure-Dart tests for the V1 fixture parser.
///
/// These do NOT spin up a real Isar instance, so they run cleanly
/// under `flutter test` on the host. The Isar round-trip layer is
/// covered by integration_test/ (which runs on a real device or
/// emulator with the native library pre-bundled).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'v1_fixture_loader.dart';

void main() {
  test('happy fixture parses into 5 rows with expected fields', () {
    final rows = parseV1Fixture(
      File('test/fixtures/bandit_state_v1_happy.json'),
    );
    expect(rows, hasLength(5));

    final help = rows.firstWhere((r) => r.buttonId == 'btn_help');
    expect(help.alpha, 4.0);
    expect(help.beta, 1.0);
    expect(help.observationCount, 5);
    expect(help.stateKey, contains('Morning_Weekday'));
  });

  test('corrupted fixture throws on the first defect (no silent drop)',
      () {
    expect(
      () => parseV1Fixture(
        File('test/fixtures/bandit_state_v1_corrupted.json'),
      ),
      throwsA(isA<FixtureLoadFailure>()),
    );
  });

  test('corrupted fixture diagnostics identify the bad row index',
      () {
    try {
      parseV1Fixture(
        File('test/fixtures/bandit_state_v1_corrupted.json'),
      );
      fail('expected FixtureLoadFailure');
    } on FixtureLoadFailure catch (e) {
      // Row 1 is the first defect (missing button_id). The parser
      // surfaces row 1's defect, not row 2 or row 3's, because it
      // throws on first encounter rather than collecting and
      // continuing.
      expect(e.diagnostics['index'], 1);
    }
  });

  test('5000-row in-memory synthesis parses fast', () {
    // The on-disk max-scale fixture lives as a generated bandit
    // population in integration_test (5000 entries x N bytes is
    // wasteful as a checked-in file). The parser handles the same
    // shape here purely as a regression on iteration cost.
    final sw = Stopwatch()..start();
    final tmp = File('${Directory.systemTemp.path}/_v1_5k.json');
    tmp.writeAsStringSync(_synth5000Json());
    final rows = parseV1Fixture(tmp);
    sw.stop();
    expect(rows, hasLength(5000));
    expect(sw.elapsed.inSeconds, lessThan(5),
        reason: 'parse of 5000 entries took ${sw.elapsed}');
    tmp.deleteSync();
  });
}

String _synth5000Json() {
  final entries = StringBuffer('[');
  for (var i = 0; i < 5000; i++) {
    if (i > 0) entries.write(',');
    entries.write(
      '{"state_key":"k_$i","button_id":"btn_$i",'
      '"alpha":1.0,"beta":1.0,"observation_count":0,'
      '"updated_at":"2026-05-28T00:00:00Z"}',
    );
  }
  entries.write(']');
  return '{"schema_version":1,"rows":$entries}';
}
