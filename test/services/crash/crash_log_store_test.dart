import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  late Directory tmp;
  late CrashLogStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('crash_store_test_');
    store = CrashLogStore(cacheDirOverride: tmp);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  CrashLog logAt(DateTime ts, {String msg = 'm'}) => CrashLog(
        timestamp: ts,
        appVersion: '0.1.0',
        buildNumber: '1',
        os: 'iOS',
        deviceModel: 'iPad',
        locale: 'en',
        exceptionType: 'TestError',
        exceptionMessage: msg,
        stackTrace: 'frame0\nframe1',
      );

  test('write creates the crash_logs subdir under the cache root', () async {
    await store.write(logAt(DateTime.utc(2026, 5, 28, 10, 0, 0)));
    final sub = Directory('${tmp.path}/${CrashLogStore.subdirName}');
    expect(sub.existsSync(), isTrue);
    expect(sub.listSync().whereType<File>(), hasLength(1));
  });

  test('rolling buffer keeps at most maxEntries (oldest pruned first)',
      () async {
    final base = DateTime.utc(2026, 1, 1);
    for (var i = 0; i < CrashLogStore.maxEntries + 5; i++) {
      await store.write(logAt(base.add(Duration(seconds: i))));
    }
    final files = await store.list();
    expect(files.length, CrashLogStore.maxEntries);
    // Oldest 5 should be gone; newest one should still exist.
    final names = files.map((f) => f.uri.pathSegments.last).toList();
    expect(names.first, contains('20260101_000005'));
    expect(names.last, contains('20260101_000024'));
  });

  test('readAll returns parsed logs in oldest-first order', () async {
    final base = DateTime.utc(2026, 1, 1);
    await store.write(logAt(base, msg: 'first'));
    await store.write(logAt(base.add(const Duration(seconds: 1)), msg: 'second'));
    final logs = await store.readAll();
    expect(logs, hasLength(2));
    expect(logs.first.exceptionMessage, 'first');
    expect(logs.last.exceptionMessage, 'second');
  });

  test('clear removes everything', () async {
    await store.write(logAt(DateTime.utc(2026, 1, 1)));
    await store.write(logAt(DateTime.utc(2026, 1, 2)));
    await store.clear();
    expect(await store.list(), isEmpty);
  });
}
