import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('reg_overlay_');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  // A minimal but valid board overlaying the bundled core_main, with a distinct
  // name so we can tell which one loaded.
  const overlayBoard = '{"schema_version":"1.3","board_id":"core_main",'
      '"board_name":"OVERLAID","grid_dimensions":[1,1],"color_key":{},'
      '"buttons":[]}';

  Future<ContentOverlayStore> _withOverlay() async {
    final store = ContentOverlayStore(dirOverride: tmp);
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {'boards/core_main.json': utf8.encode(overlayBoard)},
    );
    return store;
  }

  test('OTA overlay board wins over the bundled asset (ADR 0017)', () async {
    final registry = BoardRegistry(
      contentOverlay: await _withOverlay(),
      importedBoardsDirOverride: tmp,
    );
    final board = await registry.tryLoad('core_main');
    expect(board, isNotNull);
    expect(board!.boardName, 'OVERLAID');
  });

  test('without an overlay, the bundled asset loads', () async {
    final registry = BoardRegistry(importedBoardsDirOverride: tmp);
    final board = await registry.tryLoad('core_main');
    expect(board, isNotNull);
    expect(board!.boardName, isNot('OVERLAID'));
  });

  test('an overlay for one board does not shadow a different bundled board',
      () async {
    final registry = BoardRegistry(
      contentOverlay: await _withOverlay(),
      importedBoardsDirOverride: tmp,
    );
    final food = await registry.tryLoad('board_food');
    expect(food, isNotNull);
    expect(food!.boardName, isNot('OVERLAID'));
  });

  test('an OTA-overlaid pictogram repoints the button icon to the overlay file '
      '(ADR 0017)', () async {
    const boardWithIcon = '{"schema_version":"1.3","board_id":"core_main",'
        '"board_name":"X","grid_dimensions":[1,1],"color_key":{},"buttons":['
        '{"id":"b1","label":"Cup","type":"word","position":{"row":0,"col":0},'
        '"category":"noun","icon_uri":"assets/pictograms/cup.png",'
        '"voice_out":"cup"}]}';
    final store = ContentOverlayStore(dirOverride: tmp);
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {
        'boards/core_main.json': utf8.encode(boardWithIcon),
        'pictograms/cup.png': [9, 9, 9],
      },
    );
    final registry =
        BoardRegistry(contentOverlay: store, importedBoardsDirOverride: tmp);
    final board = await registry.tryLoad('core_main');
    final btn = board!.buttons.single;
    // iconUri was rewritten from the asset path to the overlay file path.
    expect(btn.iconUri, isNot('assets/pictograms/cup.png'));
    expect(btn.iconUri.endsWith('pictograms/cup.png'), isTrue);
    expect(File(btn.iconUri).readAsBytesSync(), [9, 9, 9]);
  });

  test('a pictogram with no overlay keeps its bundled asset path', () async {
    const boardWithIcon = '{"schema_version":"1.3","board_id":"core_main",'
        '"board_name":"X","grid_dimensions":[1,1],"color_key":{},"buttons":['
        '{"id":"b1","label":"Cup","type":"word","position":{"row":0,"col":0},'
        '"category":"noun","icon_uri":"assets/pictograms/cup.png",'
        '"voice_out":"cup"}]}';
    final store = ContentOverlayStore(dirOverride: tmp);
    // Overlay the board but NOT the pictogram file.
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {'boards/core_main.json': utf8.encode(boardWithIcon)},
    );
    final registry =
        BoardRegistry(contentOverlay: store, importedBoardsDirOverride: tmp);
    final board = await registry.tryLoad('core_main');
    expect(board!.buttons.single.iconUri, 'assets/pictograms/cup.png');
  });
}
