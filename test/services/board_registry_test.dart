import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BoardRegistry', () {
    test('knows the bundled boards', () {
      final reg = BoardRegistry();
      expect(reg.knows('core_main'), isTrue);
      expect(reg.knows('board_food'), isTrue); // now a bundled sub-board
      expect(reg.knows('not_a_real_board'), isFalse);
    });

    test('tryLoad returns null for unknown ids (not throw)', () async {
      final reg = BoardRegistry();
      final result = await reg.tryLoad('not_a_real_board');
      expect(result, isNull);
    });

    test('tryLoad returns the default board for "core_main"', () async {
      final reg = BoardRegistry();
      final board = await reg.tryLoad('core_main');
      expect(board, isNotNull);
      expect(board!.boardId, 'core_main');
      expect(board.buttons, hasLength(56));
    });

    test('registerAsset extends the registry at runtime', () async {
      final reg = BoardRegistry();
      expect(reg.knows('board_runtime_fake'), isFalse);
      reg.registerAsset('board_runtime_fake', 'boards/core_main.json');
      expect(reg.knows('board_runtime_fake'), isTrue);
      final board = await reg.tryLoad('board_runtime_fake');
      expect(board, isNotNull);
    });
  });
}
