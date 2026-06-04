/// Custom button persistence (ADR 0012, identity + counter from ADR 0014).
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
    tmp = Directory.systemTemp.createTempSync('custom_btn_test_');
    store = CustomButtonStore(dirOverride: tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  CustomButton btn(
    String id,
    int row,
    int col, {
    String label = 'X',
    String img = '',
  }) =>
      CustomButton(
        id: id,
        boardId: 'board_food',
        row: row,
        col: col,
        label: label,
        voiceOut: label.toLowerCase(),
        imagePath: img,
      );

  test('load is empty on first run', () async {
    expect(await store.load(), isEmpty);
  });

  test('add then load round-trips', () async {
    await store.add(btn('custom_board_food_0', 0, 1, label: 'Cup'));
    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.label, 'Cup');
    expect(loaded.single.col, 1);
    expect(loaded.single.id, 'custom_board_food_0');
  });

  test('adding with the same id replaces, not duplicates', () async {
    await store.add(btn('custom_board_food_0', 0, 1, label: 'First'));
    final after = await store.add(btn('custom_board_food_0', 0, 1, label: 'Second'));
    expect(after, hasLength(1));
    expect(after.single.label, 'Second');
  });

  test('two buttons that share a creation slot but differ by id both persist',
      () async {
    // ADR 0014: once a button is moved by the layout overlay, its creation slot
    // can host a second custom button. Identity is the id, not the slot, so
    // both must survive (the layout overlay separates their displayed slots).
    await store.add(btn('custom_board_food_0', 0, 1, label: 'Moved'));
    final after = await store.add(btn('custom_board_food_1', 0, 1, label: 'New'));
    expect(after, hasLength(2));
    expect(after.map((b) => b.label).toSet(), {'Moved', 'New'});
  });

  test('removeById deletes the entry and its image file', () async {
    final srcImg = File('${tmp.path}/src.png')..writeAsBytesSync([1, 2, 3]);
    final path = await store.importImage(srcImg, suggestedName: 'pic');
    expect(File(path).existsSync(), isTrue);
    await store.add(btn('custom_board_food_0', 0, 1, label: 'Cup', img: path));

    final after = await store.removeById('custom_board_food_0');
    expect(after, isEmpty);
    expect(File(path).existsSync(), isFalse, reason: 'image cleaned up');
  });

  test('allocateId is a monotonic high-water mark, never reused after delete',
      () async {
    // The headline ADR 0014 build-time guard: deleting the highest-numbered
    // custom button and then adding another must NOT reuse its id, or the new
    // button would silently inherit the deleted one's bandit posteriors.
    final id0 = await store.allocateId('board_food');
    expect(id0, 'custom_board_food_0');
    await store.add(btn(id0, 0, 1, label: 'A'));

    final id1 = await store.allocateId('board_food');
    expect(id1, 'custom_board_food_1');
    await store.add(btn(id1, 0, 2, label: 'B'));

    await store.removeById(id1);
    final id2 = await store.allocateId('board_food');
    expect(id2, 'custom_board_food_2',
        reason: 'counter is a persisted high-water mark, not max(live) + 1');
  });

  test('the counter persists across store instances (separate processes)',
      () async {
    expect(await store.allocateId('board_food'), 'custom_board_food_0');
    // A fresh store over the same dir simulates a relaunch.
    final reopened = CustomButtonStore(dirOverride: tmp);
    expect(await reopened.allocateId('board_food'), 'custom_board_food_1');
  });

  test('a legacy bare-array file loads, migrates ids, and is rewritten as an '
      'object', () async {
    File('${tmp.path}/${CustomButtonStore.fileName}').writeAsStringSync(
      jsonEncode([
        {
          'board_id': 'board_food',
          'row': 2,
          'col': 3,
          'label': 'Old',
          'voice_out': 'old',
          'image_path': '',
        },
      ]),
    );
    final loaded = await store.load();
    expect(loaded.single.id, 'custom_board_food_2_3',
        reason: 'legacy slot-derived id is reconstructed once');

    // Any save (here via allocateId) upgrades the file to the new object shape.
    await store.allocateId('board_food');
    final onDisk = jsonDecode(
      File('${tmp.path}/${CustomButtonStore.fileName}').readAsStringSync(),
    );
    expect(onDisk, isA<Map>());
    expect((onDisk as Map)['buttons'], isA<List>());
    expect(onDisk['counters'], isA<Map>());
  });

  test('importImage copies into the store, leaving the source intact', () async {
    final src = File('${tmp.path}/photo.jpg')..writeAsBytesSync([9, 9]);
    final dest = await store.importImage(src, suggestedName: 'custom_x');
    expect(dest, endsWith('.jpg'));
    expect(File(dest).existsSync(), isTrue);
    expect(src.existsSync(), isTrue);
    expect(dest, isNot(src.path));
  });

  test('importImage rejects an unsupported file type', () async {
    final src = File('${tmp.path}/notes.txt')..writeAsBytesSync([1, 2, 3]);
    expect(
      () => store.importImage(src, suggestedName: 'x'),
      throwsA(isA<CustomButtonImageException>()),
    );
  });

  test('importImage rejects an oversized image', () async {
    final src = File('${tmp.path}/huge.png')
      ..writeAsBytesSync(List.filled(CustomButtonStore.maxImageBytes + 1, 0));
    expect(
      () => store.importImage(src, suggestedName: 'x'),
      throwsA(isA<CustomButtonImageException>()),
    );
  });

  test('importImage rejects a suggestedName that is not a bare slug', () async {
    final src = File('${tmp.path}/pic.png')..writeAsBytesSync([1, 2, 3]);
    for (final name in ['../escape', 'a/b', r'a\b', '..', '']) {
      expect(
        () => store.importImage(src, suggestedName: name),
        throwsA(isA<CustomButtonImageException>()),
        reason: 'name "$name" could traverse or escape the images dir',
      );
    }
  });

  test('image path is stored relative and re-resolved against the live dir',
      () async {
    // Simulate the iOS delete-reinstall case: the app-container path changes,
    // so a persisted ABSOLUTE path would dangle. We persist the filename and
    // resolve against whatever the support dir is now.
    final src = File('${tmp.path}/photo.png')..writeAsBytesSync([1]);
    final abs = await store.importImage(src, suggestedName: 'pic');
    await store.add(btn('custom_board_food_0', 0, 1, label: 'Cup', img: abs));

    // On disk, the stored form must NOT contain the absolute container path.
    final onDisk =
        File('${tmp.path}/${CustomButtonStore.fileName}').readAsStringSync();
    expect(onDisk.contains(tmp.path), isFalse,
        reason: 'absolute container path must not be persisted');
    expect(onDisk.contains('pic.png'), isTrue);

    // Loaded form is absolute again and points under the current base dir.
    final loaded = await store.load();
    expect(loaded.single.imagePath, startsWith(tmp.path));
    expect(loaded.single.imagePath,
        endsWith('/${CustomButtonStore.imagesSubdir}/pic.png'));
  });

  test('a corrupt file loads as empty rather than throwing', () async {
    File('${tmp.path}/${CustomButtonStore.fileName}')
        .writeAsStringSync('{not valid json');
    expect(await store.load(), isEmpty);
  });
}
