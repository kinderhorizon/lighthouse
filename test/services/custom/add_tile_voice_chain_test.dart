/// Deterministic, headless reproduction of the "add a custom tile with a
/// recorded voice" chain (no widget tree). Asserts the id that the voice is
/// saved under is exactly the id the composed board tile carries, and that the
/// stored clip resolves to a real file. This is the path that shipped the
/// "Baba speaks in the robot voice" bug.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cbDir;
  late Directory cvDir;

  setUp(() {
    cbDir = Directory.systemTemp.createTempSync('chain_btn_');
    cvDir = Directory.systemTemp.createTempSync('chain_voice_');
  });
  tearDown(() {
    if (cbDir.existsSync()) cbDir.deleteSync(recursive: true);
    if (cvDir.existsSync()) cvDir.deleteSync(recursive: true);
  });

  AACBoard peopleBase() => AACBoard.fromJson(
        // A minimal People-like board with one empty slot at (0,0).
        const {
          'schema_version': '1.0',
          'board_id': 'board_people',
          'grid_dimensions': [4, 6],
          'color_key': <String, String>{},
          'buttons': <Map<String, dynamic>>[],
        },
      );

  test('add-tile flow: the composed tile id equals the voice key, and the clip '
      'file resolves', () async {
    final cbStore = CustomButtonStore(dirOverride: cbDir);
    final cvStore = CustomVoiceStore(dirOverride: cvDir);

    // Mirror BoardEditScreen._AddAtSlotDialog._save + addButton:
    final id = await cbStore.allocateId('board_people');
    await cbStore.add(CustomButton(
      id: id,
      boardId: 'board_people',
      row: 0,
      col: 0,
      label: 'Baba',
      voiceOut: 'Baba',
      imagePath: '',
    ));
    // The recorded clip the add flow hands to customVoiceProvider.save(id, clip):
    final recorded = File('${cvDir.path}/rec.m4a')
      ..writeAsBytesSync(List<int>.filled(2048, 7));
    await cvStore.importClip(recorded, buttonId: id);

    // Compose the board exactly like board_stack does.
    final buttons = await cbStore.load();
    final composed = applyCustomButtons(peopleBase(), buttons);
    final tile = composed.buttons.firstWhere((b) => b.label == 'Baba');

    // 1) The id the voice is keyed under MUST equal the tile's id.
    expect(tile.id, id, reason: 'tile id must match the voice key');

    // 2) pathFor(tile.id) resolves to a real, non-empty file.
    final voiceMap = await cvStore.load();
    final path = voiceMap[tile.id];
    expect(path, isNotNull, reason: 'voice must be stored under the tile id');
    expect(File(path!).existsSync(), isTrue, reason: 'clip file must exist');
    expect(File(path).lengthSync(), greaterThan(0),
        reason: 'clip file must be non-empty');
  });
}
