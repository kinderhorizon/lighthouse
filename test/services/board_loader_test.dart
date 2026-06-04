import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/board_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BoardLoader.loadFromAssets("boards/core_main.json")', () {
    late AACBoard board;

    setUpAll(() async {
      board = await const BoardLoader()
          .loadFromAssets('boards/core_main.json');
    });

    test('loads the v1.3 Home Core board', () {
      expect(board.schemaVersion, '1.3');
      expect(board.boardId, 'core_main');
      expect(board.boardName, 'Home Core');
    });

    test('grid is 7 rows x 8 cols', () {
      expect(board.gridDimensions, (rows: 7, cols: 8));
    });

    test('contains exactly 56 buttons (48 words + 8 fringe folders)', () {
      expect(board.buttons, hasLength(56));
    });

    test('every button position is within the grid', () {
      for (final b in board.buttons) {
        expect(b.position.row, inInclusiveRange(0, 6),
            reason: '${b.id} row out of range');
        expect(b.position.col, inInclusiveRange(0, 7),
            reason: '${b.id} col out of range');
      }
    });

    test('no two buttons share the same position', () {
      final seen = <Position>{};
      for (final b in board.buttons) {
        expect(seen.add(b.position), isTrue,
            reason: 'duplicate position at ${b.position} for ${b.id}');
      }
    });

    test('safety anchors have base_weight 0.9 (Help, Stop)', () {
      final help = board.buttons.firstWhere((b) => b.id == 'btn_help');
      final stop = board.buttons.firstWhere((b) => b.id == 'btn_stop');
      expect(help.baseWeight, 0.9);
      expect(stop.baseWeight, 0.9);
      expect(help.type, AACButtonType.phrase);
    });

    test('every button category resolves to a color in color_key', () {
      for (final b in board.buttons) {
        expect(board.colorKey.containsKey(b.category), isTrue,
            reason:
                'category "${b.category}" of ${b.id} not in color_key');
      }
    });

    test('folder buttons have link_id and null voice_out', () {
      final folders =
          board.buttons.where((b) => b.type == AACButtonType.folder);
      expect(folders, isNotEmpty);
      for (final f in folders) {
        expect(f.linkId, isNotNull,
            reason: '${f.id} folder must have link_id');
        expect(f.voiceOut, isNull,
            reason: '${f.id} folder must not have voice_out');
      }
    });

    test('buttonAt returns the right button for known positions', () {
      final what = board.buttonAt((row: 0, col: 0));
      expect(what?.id, 'btn_what');
      final i = board.buttonAt((row: 1, col: 0));
      expect(i?.id, 'btn_i');
      final allDone = board.buttonAt((row: 4, col: 7));
      expect(allDone?.id, 'btn_all_done');
    });

    test('the "I" button speaks "eye", never the bare letter', () {
      // iOS AVSpeechSynthesizer character-names lone capital letters, so
      // voice_out "I" is spoken as "Capital I". "eye" is /ai/ in any
      // English TTS, identical to the pronoun, and does not depend on any
      // engine-specific quirk. label stays "I" (what the child sees);
      // voice_out diverges by design. Do NOT regress this to "I".
      final i = board.buttons.firstWhere((b) => b.id == 'btn_i');
      expect(i.label, 'I');
      expect(i.voiceOut, 'eye');
      // General guard: no word button should have a single-character
      // voice_out (the class of inputs that triggers the iOS bug).
      for (final b in board.buttons) {
        final vo = b.voiceOut;
        if (vo != null && vo.isNotEmpty) {
          expect(vo.trim().length, greaterThan(1),
              reason: '${b.id} has a single-character voice_out "$vo", '
                  'which iOS may character-name; give it a spoken word');
        }
      }
    });
  });

  group('BoardLoader error paths', () {
    test('throws BoardLoadException on missing asset', () async {
      expect(
        () => const BoardLoader()
            .loadFromAssets('boards/does_not_exist.json'),
        throwsA(isA<BoardLoadException>()),
      );
    });

    test('rejects an oversized board file before decoding it', () async {
      final tmp = Directory.systemTemp.createTempSync('board_loader_size_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final big = File('${tmp.path}/huge.json')
        ..writeAsBytesSync(List.filled(BoardLoader.maxFileBytes + 1, 32));
      expect(
        () => const BoardLoader().loadFromFile(big),
        throwsA(isA<BoardLoadException>()),
      );
    });
  });

  group('verify pubspec asset paths are valid', () {
    test('rootBundle can read boards/core_main.json', () async {
      final raw = await rootBundle.loadString('boards/core_main.json');
      expect(raw, isNotEmpty);
    });
  });
}
