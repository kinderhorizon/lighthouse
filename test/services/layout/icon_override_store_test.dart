/// IconOverrideStore persistence (ADR 0019): per-tile "Replace picture".
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  late Directory dir;
  late File source;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('icon_override_test_');
    source = File('${dir.path}/pic.png')..writeAsBytesSync([0, 1, 2, 3]);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('empty on first run', () async {
    expect(await IconOverrideStore(dirOverride: dir).load(), isEmpty);
  });

  test('set then load returns an absolute path keyed by (board, button)',
      () async {
    final store = IconOverrideStore(dirOverride: dir);
    await store.setImage(source, boardId: 'core_main', buttonId: 'btn_eat');
    final map = await IconOverrideStore(dirOverride: dir).load();
    final key = IconOverrideStore.key('core_main', 'btn_eat');
    expect(map.containsKey(key), isTrue);
    expect(File(map[key]!).existsSync(), isTrue);
  });

  test('clear removes the image and mapping', () async {
    final store = IconOverrideStore(dirOverride: dir);
    await store.setImage(source, boardId: 'core_main', buttonId: 'btn_eat');
    final key = IconOverrideStore.key('core_main', 'btn_eat');
    final before = (await store.load())[key]!;
    await store.clear('core_main', 'btn_eat');
    final after = await IconOverrideStore(dirOverride: dir).load();
    expect(after.containsKey(key), isFalse);
    expect(File(before).existsSync(), isFalse);
  });

  test('rejects an unsupported image type', () async {
    final bad = File('${dir.path}/x.txt')..writeAsStringSync('hi');
    final store = IconOverrideStore(dirOverride: dir);
    expect(
      () => store.setImage(bad, boardId: 'core_main', buttonId: 'btn_eat'),
      throwsA(isA<IconOverrideException>()),
    );
  });
}
