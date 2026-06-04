/// Atomic file write helper (review finding: crash/power-loss safety).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/util/atomic_file.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('atomic_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('writes new content and leaves no temp file behind', () async {
    final f = File('${tmp.path}/data.json');
    await writeStringAtomically(f, '{"a":1}');
    expect(f.readAsStringSync(), '{"a":1}');
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });

  test('overwrites existing content atomically', () async {
    final f = File('${tmp.path}/data.json')..writeAsStringSync('OLD');
    await writeStringAtomically(f, 'NEW');
    expect(f.readAsStringSync(), 'NEW');
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });
}
