/// CustomVoiceStore persistence (ADR 0019): on-device clip storage by tile id.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  late Directory dir;
  late File source;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('custom_voice_test_');
    source = File('${dir.path}/rec.m4a')..writeAsBytesSync([0, 1, 2, 3, 4]);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('empty on first run', () async {
    expect(await CustomVoiceStore(dirOverride: dir).load(), isEmpty);
  });

  test('import then load returns an absolute path for the button', () async {
    final store = CustomVoiceStore(dirOverride: dir);
    await store.importClip(source, buttonId: 'btn_eat');
    final map = await CustomVoiceStore(dirOverride: dir).load();
    expect(map.containsKey('btn_eat'), isTrue);
    expect(map['btn_eat'], contains('${CustomVoiceStore.clipsSubdir}/'));
    expect(File(map['btn_eat']!).existsSync(), isTrue);
  });

  test('remove deletes the clip and the mapping', () async {
    final store = CustomVoiceStore(dirOverride: dir);
    await store.importClip(source, buttonId: 'btn_eat');
    final before = (await store.load())['btn_eat']!;
    expect(File(before).existsSync(), isTrue);
    await store.remove('btn_eat');
    final after = await CustomVoiceStore(dirOverride: dir).load();
    expect(after.containsKey('btn_eat'), isFalse);
    expect(File(before).existsSync(), isFalse);
  });

  test('rejects an unsafe button id', () async {
    final store = CustomVoiceStore(dirOverride: dir);
    expect(
      () => store.importClip(source, buttonId: '../escape'),
      throwsA(isA<CustomVoiceException>()),
    );
  });

  test('rejects a non-audio extension', () async {
    final bad = File('${dir.path}/x.txt')..writeAsStringSync('hi');
    final store = CustomVoiceStore(dirOverride: dir);
    expect(
      () => store.importClip(bad, buttonId: 'btn_eat'),
      throwsA(isA<CustomVoiceException>()),
    );
  });
}
