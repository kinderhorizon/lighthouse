import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late BoardRegistry registry;
  late BoardPackImporter importer;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pack_importer_test_');
    registry = BoardRegistry(importedBoardsDirOverride: tmp);
    importer = BoardPackImporter(registry: registry);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  File _fixture() => File('test/fixtures/core_main.json');

  test('import copies the file into the import dir and registers it',
      () async {
    final board = await importer.import(_fixture());
    expect(board.boardId, 'core_main');

    // Asset-source for core_main wins over the file source on tryLoad,
    // but the file IS registered and the file IS on disk.
    expect(registry.knows('core_main'), isTrue);
    final dest = await registry.importDestinationFor('core_main');
    expect(dest.existsSync(), isTrue);
  });

  test('importing twice overwrites the persisted file', () async {
    await importer.import(_fixture());
    final dest = await registry.importDestinationFor('core_main');
    final firstLen = dest.lengthSync();
    await importer.import(_fixture());
    expect(dest.lengthSync(), firstLen);
    expect(registry.knows('core_main'), isTrue);
  });

  test('assignFreshId imports as a separate, re-ided, namespaced board '
      '(ADR 0015)', () async {
    // core_main already exists as a bundled id; importing the same content as a
    // shared pack must NOT overwrite it but land as a fresh separate board.
    final imported = await importer.import(_fixture(), assignFreshId: true);
    expect(imported.boardId, isNot('core_main'));
    expect(imported.boardId, startsWith('imported_'));
    expect(registry.knows(imported.boardId), isTrue);
    expect(registry.knows('core_main'), isTrue); // recipient's own board intact
    // Every button id is namespaced under the new board id (ADR 0009).
    expect(
      imported.buttons.every((b) => b.id.startsWith('${imported.boardId}__')),
      isTrue,
    );
  });

  test('assignFreshId twice yields two distinct boards, no overwrite', () async {
    final a = await importer.import(_fixture(), assignFreshId: true);
    final b = await importer.import(_fixture(), assignFreshId: true);
    expect(a.boardId, isNot(b.boardId));
    expect(registry.knows(a.boardId), isTrue);
    expect(registry.knows(b.boardId), isTrue);
  });

  test('export then import round-trips meaningful fields but not ids '
      '(ADR 0015)', () async {
    const word = AACButton(
      id: 'want',
      label: 'Want',
      labelByLocale: {'es': 'Quiero'},
      type: AACButtonType.word,
      position: (row: 1, col: 2),
      category: 'verb',
      baseWeight: 0.5,
      iconUri: 'assets/want.png',
      voiceOut: 'want',
    );
    final src = AACBoard(
      schemaVersion: '1.3',
      boardId: 'board_custom_x',
      boardName: 'Mine',
      gridDimensions: (rows: 4, cols: 6),
      colorKey: const {'verb': '#ffffff'},
      buttons: const [word],
    );

    final export = await BoardPackExporter(tempDirOverride: tmp).prepare(src);
    final imported = await importer.import(export.file, assignFreshId: true);

    expect(imported.boardId, isNot('board_custom_x')); // re-ided
    final b = imported.buttons.single;
    expect(b.id, isNot('want')); // namespaced
    expect(b.label, 'Want'); // meaningful fields survive
    expect(b.labelByLocale['es'], 'Quiero');
    expect(b.position, (row: 1, col: 2));
    expect(b.voiceOut, 'want');
    expect(b.iconUri, 'assets/want.png');
  });

  test('assignFreshId drops a non-asset icon_uri but keeps an asset one '
      '(import-path hardening)', () async {
    // A crafted pack can carry an absolute icon_uri: it passes AACButton parse
    // (absolute paths are legal for bundled/overlay art), so the importer is
    // the layer that must refuse to keep an arbitrary on-device path. An
    // assets-relative icon is legitimate and must survive.
    final crafted = File('${tmp.path}/crafted.json');
    crafted.writeAsStringSync(jsonEncode({
      'schema_version': '1.0',
      'board_id': 'sender_board',
      'grid_dimensions': [4, 6],
      'color_key': <String, String>{},
      'buttons': [
        {
          'id': 'evil',
          'label': 'Evil',
          'type': 'word',
          'voice_out': 'evil',
          'position': {'row': 0, 'col': 0},
          'category': 'noun',
          'base_weight': 0.5,
          'icon_uri': '/data/data/other.app/files/secret.png',
        },
        {
          'id': 'ok',
          'label': 'Ok',
          'type': 'word',
          'voice_out': 'ok',
          'position': {'row': 0, 'col': 1},
          'category': 'noun',
          'base_weight': 0.5,
          'icon_uri': 'assets/pictograms/cup.png',
        },
      ],
    }));

    final imported = await importer.import(crafted, assignFreshId: true);
    final evil = imported.buttons.firstWhere((b) => b.id.endsWith('__evil'));
    final ok = imported.buttons.firstWhere((b) => b.id.endsWith('__ok'));
    expect(evil.iconUri, '', reason: 'arbitrary device path must be dropped');
    expect(ok.iconUri, 'assets/pictograms/cup.png',
        reason: 'a bundled-asset icon is legitimate and kept');
  });

  test('verbatim import (assignFreshId: false) also sanitizes a non-asset '
      'icon_uri and persists it sanitized (review L2)', () async {
    final crafted = File('${tmp.path}/verbatim.json');
    crafted.writeAsStringSync(jsonEncode({
      'schema_version': '1.0',
      'board_id': 'verbatim_board',
      'grid_dimensions': [4, 6],
      'color_key': <String, String>{},
      'buttons': [
        {
          'id': 'evil',
          'label': 'Evil',
          'type': 'word',
          'voice_out': 'evil',
          'position': {'row': 0, 'col': 0},
          'category': 'noun',
          'base_weight': 0.5,
          'icon_uri': '/etc/passwd',
        },
      ],
    }));

    // Default path keeps the board id (verbatim contract) but must still drop
    // the arbitrary device path, and the PERSISTED file must be sanitized too
    // so a hydrate re-parse cannot resurrect it.
    final imported = await importer.import(crafted);
    expect(imported.boardId, 'verbatim_board');
    expect(imported.buttons.single.iconUri, '');

    final dest = await registry.importDestinationFor('verbatim_board');
    final reparsed = AACBoard.fromJson(
        jsonDecode(dest.readAsStringSync()) as Map<String, dynamic>);
    expect(reparsed.buttons.single.iconUri, '');
  });

  group('rejects a pack with an unsafe button id / link_id (ADR 0021 F)', () {
    Future<void> expectRejected(String id, {String? linkId}) async {
      final crafted = File('${tmp.path}/unsafe_${id.hashCode}.json');
      crafted.writeAsStringSync(jsonEncode({
        'schema_version': '1.0',
        'board_id': 'sender_board',
        'grid_dimensions': [4, 6],
        'color_key': <String, String>{},
        'buttons': [
          {
            'id': id,
            'label': 'X',
            'type': linkId == null ? 'word' : 'folder',
            'voice_out': 'x',
            'position': {'row': 0, 'col': 0},
            'category': 'noun',
            'base_weight': 0.5,
            if (linkId != null) 'link_id': linkId,
          },
        ],
      }));
      // Rejected on BOTH paths: the namespacing prefix does not neutralize a
      // separator/`..`/delimiter already inside the id.
      await expectLater(importer.import(crafted),
          throwsA(isA<BoardPackImportException>()));
      await expectLater(importer.import(crafted, assignFreshId: true),
          throwsA(isA<BoardPackImportException>()));
    }

    test('path separator in id', () => expectRejected('a/b'));
    test('parent traversal in id', () => expectRejected('..'));
    test('bandit delimiter "|" in id', () => expectRejected('foo|bar'));
    test('bandit delimiter ":" in id', () => expectRejected('foo:bar'));
    test('unsafe link_id (folder) is also rejected',
        () => expectRejected('safe_folder', linkId: 'tgt/../escape'));
  });

  test('import of a missing file throws BoardPackImportException',
      () async {
    expect(
      () => importer.import(File('${tmp.path}/does_not_exist.json')),
      throwsA(isA<BoardPackImportException>()),
    );
  });

  test('import of malformed JSON throws BoardPackImportException',
      () async {
    final bad = File('${tmp.path}/bad.json')..writeAsStringSync('{');
    expect(
      () => importer.import(bad),
      throwsA(isA<BoardPackImportException>()),
    );
  });

  test('hydrate picks up persisted imports on a fresh registry instance',
      () async {
    // Round 1: import a fixture renamed to a non-bundled boardId so the
    // file source is the only thing that can resolve it on the cold
    // registry (the bundled asset map always contains core_main).
    final renamed = File('${tmp.path}/board_custom.json');
    final raw = _fixture().readAsStringSync().replaceAll(
        '"board_id": "core_main"', '"board_id": "board_custom"');
    renamed.writeAsStringSync(raw);
    await importer.import(renamed);

    // Round 2: fresh registry pointing at the same persistent import
    // dir. The board_custom id is NOT in the asset map; hydration is the
    // only path that registers it.
    final cold = BoardRegistry(importedBoardsDirOverride: tmp);
    expect(cold.knows('board_custom'), isFalse);

    await cold.hydrate();

    expect(cold.knows('board_custom'), isTrue);
    final loaded = await cold.tryLoad('board_custom');
    expect(loaded, isNotNull);
    expect(loaded!.boardId, 'board_custom');
  });
}
