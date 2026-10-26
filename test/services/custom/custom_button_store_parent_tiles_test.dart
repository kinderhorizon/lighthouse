/// Custom button store, ADR 0022 additions, on REAL files in a temp dir:
/// colour / replacement / category fields persist, edits replace in place,
/// a category is deleted with everything on it in one write, page ids are never
/// reused, and old photos are cleaned up only inside the store's own folder.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  late Directory tmp;
  late CustomButtonStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('custom_btn_022_');
    store = CustomButtonStore(dirOverride: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  CustomButton btn(
    String id, {
    String boardId = 'core_main',
    String img = '',
    TileColor? color,
    String? replaces,
    String? link,
  }) =>
      CustomButton(
        id: id,
        boardId: boardId,
        row: 0,
        col: 0,
        label: id,
        voiceOut: id,
        imagePath: img,
        tileColor: color,
        replacesId: replaces,
        linkId: link,
      );

  File fileOnDisk() => File('${tmp.path}/${CustomButtonStore.fileName}');

  File photo(String name) {
    final dir = Directory('${tmp.path}/${CustomButtonStore.imagesSubdir}')
      ..createSync(recursive: true);
    return File('${dir.path}/$name')..writeAsBytesSync([1, 2, 3]);
  }

  test('colour, replacement and category link persist across a reload',
      () async {
    await store.add(btn('a', color: TileColor.green, replaces: 'want'));
    await store.add(btn('b', color: TileColor.yellow, link: 'cat_0'));
    final fresh = CustomButtonStore(dirOverride: tmp);
    final loaded = await fresh.load();
    expect(loaded.map((b) => (b.id, b.tileColor, b.replacesId, b.linkId)), [
      ('a', TileColor.green, 'want', null),
      ('b', TileColor.yellow, null, 'cat_0'),
    ]);
  });

  test('update replaces IN PLACE, keeping order and the relative photo path',
      () async {
    final img = photo('a.png');
    await store.add(btn('a', img: img.path));
    await store.add(btn('b'));
    await store.add(btn('c'));
    final loaded = await store.load();
    final edited = loaded[0].withTileColor(TileColor.blue);
    final after = await store.update(edited);
    expect(after.map((b) => b.id), ['a', 'b', 'c']);
    expect(after.first.tileColor, TileColor.blue);
    expect(after.first.imagePath, img.path);
    // On disk the photo is still a bare filename (survives a restore).
    final raw = jsonDecode(fileOnDisk().readAsStringSync()) as Map;
    expect((raw['buttons'] as List).first['image_path'], 'a.png');
  });

  test('update of an unknown id changes nothing', () async {
    await store.add(btn('a'));
    final before = fileOnDisk().readAsStringSync();
    final after = await store.update(btn('zzz', color: TileColor.pink));
    expect(after.map((b) => b.id), ['a']);
    expect(fileOnDisk().readAsStringSync(), before);
  });

  test('removeMany deletes the buttons and their photos in one write',
      () async {
    final pa = photo('a.png');
    final pb = photo('b.png');
    await store.add(btn('a', img: pa.path, link: 'cat_0'));
    await store.add(btn('b', boardId: 'cat_0', img: pb.path));
    await store.add(btn('keep'));
    final id = await store.allocateId('core_main');
    final after = await store.removeMany({'a', 'b'});
    expect(after.map((b) => b.id), ['keep']);
    expect(pa.existsSync(), isFalse);
    expect(pb.existsSync(), isFalse);
    // Counters are kept: the next id is never a reused one.
    expect(await store.allocateId('core_main'), isNot(id));
  });

  test('category page ids count up and are never reused, even after a reset',
      () async {
    expect(await store.allocateCategoryBoardId(), 'cat_0');
    expect(await store.allocateCategoryBoardId(), 'cat_1');
    await store.clearAll();
    expect(await store.allocateCategoryBoardId(), 'cat_2');
    // Separate from the per-board button counters.
    expect(await store.allocateId('core_main'), 'custom_core_main_0');
    final fresh = CustomButtonStore(dirOverride: tmp);
    expect(await fresh.allocateCategoryBoardId(), 'cat_3');
  });

  test('category page ids are valid board ids', () async {
    for (var i = 0; i < 3; i++) {
      expect(AACBoard.isValidBoardId(await store.allocateCategoryBoardId()),
          isTrue);
    }
  });

  test('on a corrupt file every new mutator refuses instead of wiping',
      () async {
    fileOnDisk().writeAsStringSync('{not json');
    final before = fileOnDisk().readAsStringSync();
    await expectLater(
        store.update(btn('a')), throwsA(isA<CustomButtonStoreReadException>()));
    await expectLater(store.removeMany({'a'}),
        throwsA(isA<CustomButtonStoreReadException>()));
    await expectLater(store.allocateCategoryBoardId(),
        throwsA(isA<CustomButtonStoreReadException>()));
    expect(fileOnDisk().readAsStringSync(), before);
  });

  test('deleteImage removes only a file directly in the images folder',
      () async {
    final inside = photo('old.png');
    final outside = File('${tmp.path}/precious.json')..writeAsStringSync('x');
    await store.deleteImage(outside.path);
    await store.deleteImage('${tmp.path}/${CustomButtonStore.imagesSubdir}/../precious.json');
    await store.deleteImage('');
    await store.deleteImage('relative.png');
    expect(outside.existsSync(), isTrue);
    await store.deleteImage(inside.path);
    expect(inside.existsSync(), isFalse);
  });
}
