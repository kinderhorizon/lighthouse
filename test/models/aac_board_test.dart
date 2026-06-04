/// AACBoard parsing guards, including the board_id path-traversal rejection.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';

Map<String, dynamic> _boardJson(String boardId) => {
      'schema_version': '1.3',
      'board_id': boardId,
      'grid_dimensions': [7, 8],
      'color_key': <String, String>{},
      'buttons': <Map<String, dynamic>>[],
    };

void main() {
  group('AACBoard.isValidBoardId', () {
    test('accepts bundled-style slugs', () {
      for (final ok in ['core_main', 'board_food', 'board-body', 'a', 'A1_b-2']) {
        expect(AACBoard.isValidBoardId(ok), isTrue, reason: ok);
      }
    });

    test('rejects traversal and path separators', () {
      for (final bad in [
        '../../evil',
        '..',
        'a/b',
        r'a\b',
        'foo.json',
        'with space',
        '', // empty
        'x' * 65, // too long
      ]) {
        expect(AACBoard.isValidBoardId(bad), isFalse, reason: bad);
      }
    });
  });

  group('AACBoard.fromJson board_id guard (path-traversal defense)', () {
    test('parses a valid board_id', () {
      final board = AACBoard.fromJson(_boardJson('board_food'));
      expect(board.boardId, 'board_food');
    });

    test('rejects a traversal board_id (would escape the import dir)', () {
      expect(
        () => AACBoard.fromJson(_boardJson('../../lighthouse_db')),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a board_id containing a path separator', () {
      expect(
        () => AACBoard.fromJson(_boardJson('sub/dir')),
        throwsA(isA<FormatException>()),
      );
    });

    test('still rejects a missing board_id', () {
      final json = _boardJson('x')..remove('board_id');
      expect(() => AACBoard.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
