/// Board layout persistence (ADR 0014).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  late Directory tmp;
  late BoardLayoutStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('board_layout_test_');
    store = BoardLayoutStore(dirOverride: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('load is empty on first run', () async {
    expect((await store.load()).isEmpty, isTrue);
  });

  test('save then load round-trips', () async {
    final layout = const BoardLayout.empty()
        .withPosition('core_main', 'btn_want', (row: 2, col: 3));
    await store.save(layout);
    final back = await store.load();
    expect(back.positionOf('core_main', 'btn_want'), (row: 2, col: 3));
  });

  test('a corrupt file loads as empty rather than throwing', () async {
    File('${tmp.path}/${BoardLayoutStore.fileName}')
        .writeAsStringSync('{not valid json');
    expect((await store.load()).isEmpty, isTrue);
  });

  test('a non-object json loads as empty', () async {
    File('${tmp.path}/${BoardLayoutStore.fileName}').writeAsStringSync('[1,2,3]');
    expect((await store.load()).isEmpty, isTrue);
  });
}
