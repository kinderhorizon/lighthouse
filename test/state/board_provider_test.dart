/// defaultBoardProvider routing (ADR 0017 regression).
///
/// The home board (core_main) is the most-used board, so it MUST be OTA-fixable.
/// This pins that defaultBoardProvider resolves through the board registry (and
/// therefore the content overlay), not the asset bundle directly. A regression
/// to `BoardLoader().loadFromAssets('boards/core_main.json')` would make this
/// fail: the overlaid name would not load.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('default_board_');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  const overlaidCoreMain = '{"schema_version":"1.3","board_id":"core_main",'
      '"board_name":"OVERLAID_HOME","grid_dimensions":[1,1],"color_key":{},'
      '"buttons":[]}';

  test('defaultBoardProvider honors an OTA overlay on the home board', () async {
    final store = ContentOverlayStore(dirOverride: tmp);
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {'boards/core_main.json': utf8.encode(overlaidCoreMain)},
    );
    final registry =
        BoardRegistry(contentOverlay: store, importedBoardsDirOverride: tmp);

    final container = ProviderContainer(overrides: [
      boardRegistryProvider.overrideWith((ref) async => registry),
    ]);
    addTearDown(container.dispose);

    final board = await container.read(defaultBoardProvider.future);
    expect(board.boardId, 'core_main');
    expect(board.boardName, 'OVERLAID_HOME',
        reason: 'home board must load through the registry/overlay, not the '
            'asset bundle directly');
  });

  test('defaultBoardProvider loads the bundled home board without an overlay',
      () async {
    final registry = BoardRegistry(importedBoardsDirOverride: tmp);
    final container = ProviderContainer(overrides: [
      boardRegistryProvider.overrideWith((ref) async => registry),
    ]);
    addTearDown(container.dispose);

    final board = await container.read(defaultBoardProvider.future);
    expect(board.boardId, 'core_main');
    expect(board.boardName, isNot('OVERLAID_HOME'));
  });
}
