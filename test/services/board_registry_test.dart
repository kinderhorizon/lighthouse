import 'dart:io';

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

  group('shared board ids (ADR 0023)', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('registry_ids_');
    });
    tearDown(() => dir.delete(recursive: true));

    Future<void> addShared(BoardRegistry reg, String id) async {
      final f = await reg.importDestinationFor(id);
      f.writeAsStringSync('{"schema_version":"1.3","board_id":"$id",'
          '"grid_dimensions":[1,1],"buttons":[]}');
      reg.registerFile(id, f.path);
    }

    test('a deleted shared board id is never handed out again', () async {
      final reg = BoardRegistry(importedBoardsDirOverride: dir);
      final first = await reg.allocateImportedBoardId();
      await addShared(reg, first);
      final second = await reg.allocateImportedBoardId();
      await addShared(reg, second);
      expect([first, second], ['imported_1', 'imported_2']);

      await reg.removeImported(second);
      expect(reg.knows(second), isFalse);
      expect(reg.importedBoardIds(), [first]);
      expect(File('${dir.path}/imported_boards/$second.json').existsSync(),
          isFalse);
      expect(await reg.allocateImportedBoardId(), 'imported_3');

      // And not after a restart either.
      final again = BoardRegistry(importedBoardsDirOverride: dir);
      await again.hydrate();
      expect(again.importedBoardIds(), [first]);
      expect(await again.allocateImportedBoardId(), 'imported_4');
    });

    test('boards from before the mark existed are counted', () async {
      final reg = BoardRegistry(importedBoardsDirOverride: dir);
      await addShared(reg, 'imported_5');
      expect(await reg.allocateImportedBoardId(), 'imported_6');
    });

    test('bundled boards cannot be deleted', () async {
      final reg = BoardRegistry(importedBoardsDirOverride: dir);
      await reg.removeImported('core_main');
      expect(reg.knows('core_main'), isTrue);
      expect(reg.bundledBoardIds(), contains('core_main'));
      expect(reg.importedBoardFile('core_main'), isNull);
    });
  });
}
