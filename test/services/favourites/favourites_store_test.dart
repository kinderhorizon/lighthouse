/// Home-favourite pin persistence (ADR 0013).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  late Directory tmp;
  late FavouritesStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fav_store_test_');
    store = FavouritesStore(dirOverride: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  ButtonRef r(String id, [String b = 'board_food']) =>
      (boardId: b, buttonId: id);

  test('empty on first run', () async {
    expect(await store.pins(), isEmpty);
  });

  test('pin then load round-trips in order', () async {
    await store.pin(r('apple'));
    await store.pin(r('cookie'));
    expect(await store.pins(), [r('apple'), r('cookie')]);
  });

  test('pinning the same ref twice does not duplicate', () async {
    await store.pin(r('apple'));
    final after = await store.pin(r('apple'));
    expect(after, [r('apple')]);
  });

  test('unpin removes the ref', () async {
    await store.pin(r('apple'));
    await store.pin(r('cookie'));
    final after = await store.unpin(r('apple'));
    expect(after, [r('cookie')]);
  });

  test('corrupt file loads as empty', () async {
    File('${tmp.path}/${FavouritesStore.fileName}')
        .writeAsStringSync('not json');
    expect(await store.pins(), isEmpty);
  });
}
