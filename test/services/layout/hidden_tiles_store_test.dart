/// HiddenTilesStore persistence (ADR 0019).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hidden_tiles_test_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('empty on first run', () async {
    final store = HiddenTilesStore(dirOverride: dir);
    expect((await store.load()).isEmpty, isTrue);
  });

  test('save then load round-trips through a fresh instance', () async {
    final w = HiddenTilesStore(dirOverride: dir);
    await w.save(const HiddenTiles.empty()
        .withBulkVisibility('core_main', ['btn_a', 'btn_b'], true));
    final r = await HiddenTilesStore(dirOverride: dir).load();
    expect(r.isHidden('core_main', 'btn_a'), isTrue);
    expect(r.isHidden('core_main', 'btn_b'), isTrue);
    expect(r.isHidden('core_main', 'btn_c'), isFalse);
  });

  test('a corrupt file loads as empty', () async {
    File('${dir.path}/${HiddenTilesStore.fileName}')
        .writeAsStringSync('not json{');
    final r = await HiddenTilesStore(dirOverride: dir).load();
    expect(r.isEmpty, isTrue);
  });
}
