/// V1 fixture loader.
///
/// Test-only helper. The pure-Dart [parseV1Fixture] is testable in
/// any environment (used by the unit tests below). [loadV1Fixture]
/// adds the Isar write on top; that path runs in
/// `integration_test/` (or via `dart test` on a platform that has
/// the Isar native library pre-installed), not under `flutter test`
/// on the host, because `flutter_test`'s HTTP override blocks
/// Isar.initializeIsarCore from downloading the native binary.
library;

import 'dart:convert';
import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:lighthouse/persistence/persistence.dart';

class FixtureLoadFailure implements Exception {
  const FixtureLoadFailure({
    required this.reason,
    required this.diagnostics,
  });

  final String reason;
  final Map<String, dynamic> diagnostics;

  @override
  String toString() =>
      'FixtureLoadFailure($reason, diagnostics=$diagnostics)';
}

/// Pure-Dart parse + validation from a [File]. Convenience wrapper over
/// [parseV1FixtureString] for host-mode unit tests where reading a file
/// by relative path works. On-device callers (integration_test) should
/// use [parseV1FixtureString] with content they obtained portably (the
/// app sandbox has no `test/fixtures/` directory).
List<BanditStateV1> parseV1Fixture(File file) =>
    parseV1FixtureString(file.readAsStringSync());

/// Pure-Dart parse + validation from a JSON string. Returns the parsed
/// rows ready to write via the bandit repository. Throws
/// [FixtureLoadFailure] on any defect; does NOT silently drop rows.
List<BanditStateV1> parseV1FixtureString(String jsonStr) {
  final raw = jsonDecode(jsonStr) as Map<String, dynamic>;
  final rows = (raw['rows'] as List).cast<dynamic>();

  final parsed = <BanditStateV1>[];
  for (var i = 0; i < rows.length; i++) {
    final entry = rows[i];
    if (entry is! Map<String, dynamic>) {
      throw FixtureLoadFailure(
        reason: 'row $i is not an object',
        diagnostics: {'index': i, 'value': entry},
      );
    }
    final stateKey = entry['state_key'];
    final buttonId = entry['button_id'];
    final alpha = entry['alpha'];
    final beta = entry['beta'];
    final observationCount = entry['observation_count'];
    final updatedAtRaw = entry['updated_at'];

    if (stateKey is! String || stateKey.isEmpty) {
      throw FixtureLoadFailure(
        reason: 'row $i: missing or non-string state_key',
        diagnostics: {'index': i},
      );
    }
    if (buttonId is! String || buttonId.isEmpty) {
      throw FixtureLoadFailure(
        reason: 'row $i: missing or non-string button_id',
        diagnostics: {'index': i, 'state_key': stateKey},
      );
    }
    if (alpha is! num) {
      throw FixtureLoadFailure(
        reason: 'row $i: alpha is not a number',
        diagnostics: {'index': i, 'value': alpha},
      );
    }
    if (beta is! num) {
      throw FixtureLoadFailure(
        reason: 'row $i: beta is not a number',
        diagnostics: {'index': i, 'value': beta},
      );
    }
    if (alpha < 0 || beta < 0) {
      throw FixtureLoadFailure(
        reason: 'row $i: negative alpha or beta',
        diagnostics: {'index': i, 'alpha': alpha, 'beta': beta},
      );
    }
    if (observationCount is! int || observationCount < 0) {
      throw FixtureLoadFailure(
        reason: 'row $i: observation_count must be a non-negative integer',
        diagnostics: {'index': i, 'value': observationCount},
      );
    }

    parsed.add(BanditStateV1()
      ..stateKey = stateKey
      ..buttonId = buttonId
      ..alpha = (alpha).toDouble()
      ..beta = (beta).toDouble()
      ..observationCount = observationCount
      ..updatedAt = updatedAtRaw is String
          ? DateTime.parse(updatedAtRaw)
          : DateTime.now().toUtc());
  }
  return parsed;
}

/// Parse + persist from a [File]. Host-mode convenience.
Future<int> loadV1Fixture(File file, Isar isar) async {
  return loadV1FixtureString(file.readAsStringSync(), isar);
}

/// Parse + persist from a JSON string. Used by integration tests on a
/// real device, where a relative file path does not resolve but a real
/// Isar instance is available.
Future<int> loadV1FixtureString(String jsonStr, Isar isar) async {
  final rows = parseV1FixtureString(jsonStr);
  await BanditRepository(isar).putStateAll(rows);
  return rows.length;
}
