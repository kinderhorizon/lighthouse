/// Manifest integrity tests.
///
/// Asserts the relationship between boards/core_main.json, the on-disk
/// PNG files under assets/arasaac/, and assets/arasaac/manifest.json
/// holds at all times:
///
/// - Every button's icon_uri in the default board has a manifest entry.
/// - Every manifest entry's icon_uri points to a real file on disk.
/// - Every on-disk file matches the manifest's sha256.
///
/// This is the test-time equivalent of tools/verify_assets.dart and runs
/// in CI alongside flutter test, so we catch drift before it lands.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Set<String> boardIconUris;
  late Map<String, dynamic> manifest;
  late List<Map<String, dynamic>> manifestSymbols;

  setUpAll(() {
    // Every board under boards/, not just core_main: the manifest must cover
    // the union of all boards' icons with no orphans either way.
    boardIconUris = <String>{};
    for (final f in Directory('boards')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final b = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      for (final btn in (b['buttons'] as List).cast<Map<String, dynamic>>()) {
        boardIconUris.add(btn['icon_uri'] as String);
      }
    }
    manifest = jsonDecode(File('assets/arasaac/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    manifestSymbols =
        (manifest['symbols'] as List).cast<Map<String, dynamic>>();
  });

  test('manifest covers all board icons (no orphans either way)', () {
    final manifestIconUris =
        manifestSymbols.map((s) => s['icon_uri'] as String).toSet();

    expect(manifestIconUris.difference(boardIconUris), isEmpty,
        reason: 'manifest entries point to icons the board does not use');
    expect(boardIconUris.difference(manifestIconUris), isEmpty,
        reason: 'board uses icons the manifest does not cover');
  });

  test('every manifest icon_uri points to a real file on disk', () {
    for (final entry in manifestSymbols) {
      final iconUri = entry['icon_uri'] as String;
      expect(File(iconUri).existsSync(), isTrue,
          reason: 'expected file on disk: $iconUri');
    }
  });

  test('every on-disk file matches the manifest sha256', () {
    for (final entry in manifestSymbols) {
      final iconUri = entry['icon_uri'] as String;
      final expected = entry['sha256'] as String;
      final bytes = File(iconUri).readAsBytesSync();
      final actual = sha256.convert(bytes).toString();
      expect(actual, expected,
          reason: 'sha256 mismatch for $iconUri; '
              'run `dart run tools/verify_assets.dart` to confirm');
    }
  });

  test('manifest checksum_policy describes the verifier', () {
    final policy = manifest['checksum_policy'] as Map<String, dynamic>;
    expect(policy['algorithm'], 'sha256');
    expect(policy['verifier'], 'tools/verify_assets.dart');
    expect(policy['phase'], 'Phase 1');
  });
}
