import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';

AACBoard _board(List<AACButton> buttons) => AACBoard(
      schemaVersion: '1.3',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 4, cols: 6),
      colorKey: const {'verb': '#ffffff', 'custom': '#eeeeee', 'nav': '#dddddd'},
      buttons: buttons,
    );

void main() {
  test('buildExportBoard drops folders and degrades photo buttons to text-only',
      () {
    const folder = AACButton(
      id: 'f',
      label: 'Food',
      labelByLocale: {},
      type: AACButtonType.folder,
      position: (row: 0, col: 0),
      category: 'nav',
      baseWeight: 0.5,
      iconUri: 'assets/f.png',
      linkId: 'board_food',
    );
    const photo = AACButton(
      id: 'p',
      label: 'Mom',
      labelByLocale: {},
      type: AACButtonType.word,
      position: (row: 0, col: 1),
      category: kCustomCategory,
      baseWeight: 0.5,
      iconUri: '/data/app/img_p.png',
      voiceOut: 'Mom',
    );
    const word = AACButton(
      id: 'want',
      label: 'Want',
      labelByLocale: {},
      type: AACButtonType.word,
      position: (row: 0, col: 2),
      category: 'verb',
      baseWeight: 0.5,
      iconUri: 'assets/want.png',
      voiceOut: 'want',
    );

    final result = BoardPackExporter.buildExportBoard(_board([folder, photo, word]));

    expect(result.foldersDropped, 1);
    expect(result.photosAsTextOnly, 1);

    final ids = result.board.buttons.map((b) => b.id).toList();
    expect(ids, containsAll(<String>['p', 'want']));
    expect(ids, isNot(contains('f'))); // folder dropped

    final pBtn = result.board.buttons.firstWhere((b) => b.id == 'p');
    expect(pBtn.iconUri, ''); // photo stripped...
    expect(pBtn.label, 'Mom'); // ...but the word is kept
    expect(pBtn.voiceOut, 'Mom');

    // A bundled-asset word is untouched.
    final wantBtn = result.board.buttons.firstWhere((b) => b.id == 'want');
    expect(wantBtn.iconUri, 'assets/want.png');
  });

  test('blanks an OTA-overlaid (absolute-path) icon without counting it as a '
      'photo (review L1)', () {
    const overlaid = AACButton(
      id: 'o',
      label: 'Help',
      labelByLocale: {},
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: 'verb', // NOT custom: an OTA-overlaid pictogram, not a photo
      baseWeight: 0.5,
      iconUri: '/var/mobile/Containers/Data/Application/X/content_overlay/v/3/h.png',
      voiceOut: 'Help',
    );
    const asset = AACButton(
      id: 'a',
      label: 'Go',
      labelByLocale: {},
      type: AACButtonType.word,
      position: (row: 0, col: 1),
      category: 'verb',
      baseWeight: 0.5,
      iconUri: 'assets/pictograms/go.png',
      voiceOut: 'Go',
    );
    final built = BoardPackExporter.buildExportBoard(_board([overlaid, asset]));
    final o = built.board.buttons.firstWhere((b) => b.id == 'o');
    final a = built.board.buttons.firstWhere((b) => b.id == 'a');
    expect(o.iconUri, '',
        reason: 'an absolute container path must not leave the device');
    expect(a.iconUri, 'assets/pictograms/go.png',
        reason: 'a bundled-asset icon transfers unchanged');
    expect(built.photosAsTextOnly, 0,
        reason: 'an overlaid pictogram is not a custom photo');
  });

  test('prepare writes a temp pack that re-parses to the export board',
      () async {
    final tmp = await Directory.systemTemp.createTemp('exporter_test_');
    addTearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });
    const word = AACButton(
      id: 'want',
      label: 'Want',
      labelByLocale: {},
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: 'verb',
      baseWeight: 0.5,
      iconUri: 'assets/want.png',
      voiceOut: 'want',
    );

    final export =
        await BoardPackExporter(tempDirOverride: tmp).prepare(_board([word]));

    expect(export.file.existsSync(), isTrue);
    final reparsed = AACBoard.fromJson(
      jsonDecode(export.file.readAsStringSync()) as Map<String, dynamic>,
    );
    expect(reparsed.boardId, 'core_main'); // export keeps original id; import re-ids
    expect(reparsed.buttons.single.id, 'want');
    expect(reparsed.buttons.single.voiceOut, 'want');
  });

  // Privacy contract (close-out of the vocab-export review gate, 2026-05-31).
  //
  // A shared pack must carry vocabulary STRUCTURE only, never the child's
  // learned usage (bandit posteriors in `bandit_state_v1`, the raw tap log in
  // `raw_event_log_v1`) or their photos. That holds structurally because the
  // export is exactly `AACBoard.toJson()` and the board model cannot reach
  // those Isar collections. These tests PIN the emitted key set so a future
  // field added to either `toJson` fails CI and forces a conscious "is this
  // child-usage data?" review before it can ship inside a pack. Same
  // enforcement model as `test/privacy/backup_exclusion_test.dart`.
  test('AACButton.toJson emits ONLY the contracted keys (no usage leak)', () {
    // A maximal button: every optional field populated so every possible key
    // is emitted (localized values are ASCII placeholders; only their keys,
    // label_<code> / voice_out_<code>, matter to this contract).
    const maximal = AACButton(
      id: 'p',
      label: 'Mom',
      labelByLocale: {'ar': 'mama', 'es': 'mama'},
      type: AACButtonType.word,
      position: (row: 1, col: 2),
      category: 'noun',
      baseWeight: 0.5,
      iconUri: 'assets/p.png',
      voiceOut: 'Mom',
      voiceOutByLocale: {'ar': 'mama', 'es': 'mama'},
      linkId: 'board_food',
    );

    const allowedExact = <String>{
      'id',
      'label',
      'type',
      'position',
      'category',
      'base_weight',
      'icon_uri',
      'voice_out',
      'link_id',
    };
    const allowedPrefixes = <String>['label_', 'voice_out_'];

    final keys = maximal.toJson().keys.toSet();
    final unexpected = keys.where((k) =>
        !allowedExact.contains(k) &&
        !allowedPrefixes.any((p) => k.startsWith(p)));
    expect(unexpected, isEmpty,
        reason: 'New AACButton.toJson key(s) $unexpected: a shared pack must '
            'not carry child usage data. Confirm the key is vocabulary '
            'structure, then add it to the allow-list above.');
    // Every contracted key is actually present (also catches a silent drop).
    expect(keys, containsAll(allowedExact));
  });

  test('AACBoard.toJson emits ONLY the contracted keys (no usage leak)', () {
    final maximal = AACBoard(
      schemaVersion: '1.3',
      boardId: 'core_main',
      boardName: 'Home',
      boardNameByLocale: const {'ar': 'home', 'es': 'home'},
      gridDimensions: (rows: 4, cols: 6),
      colorKey: const {'verb': '#ffffff'},
      buttons: const [],
    );

    const allowedExact = <String>{
      'schema_version',
      'board_id',
      'board_name',
      'grid_dimensions',
      'color_key',
      'buttons',
    };
    const allowedPrefixes = <String>['board_name_'];

    final keys = maximal.toJson().keys.toSet();
    final unexpected = keys.where((k) =>
        !allowedExact.contains(k) &&
        !allowedPrefixes.any((p) => k.startsWith(p)));
    expect(unexpected, isEmpty,
        reason: 'New AACBoard.toJson key(s) $unexpected: a shared pack must '
            'not carry child usage data. Confirm the key is vocabulary '
            'structure, then add it to the allow-list above.');
    expect(keys, containsAll(allowedExact));
  });
}
