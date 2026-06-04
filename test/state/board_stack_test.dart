import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/state/state.dart';

void main() {
  late AACBoard rootBoard;
  late AACBoard subBoardA;
  late AACBoard subBoardB;

  setUpAll(() {
    final raw = File('test/fixtures/core_main.json').readAsStringSync();
    rootBoard = AACBoard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    // Construct minimal alt boards reusing the parsed JSON shape.
    subBoardA = AACBoard.fromJson(
        (jsonDecode(raw) as Map<String, dynamic>)..['board_id'] = 'sub_a');
    subBoardB = AACBoard.fromJson(
        (jsonDecode(raw) as Map<String, dynamic>)..['board_id'] = 'sub_b');
  });

  ProviderContainer _container() {
    return ProviderContainer(overrides: [
      defaultBoardProvider.overrideWith((ref) async => rootBoard),
    ]);
  }

  test('build seeds the stack with the default board once it resolves',
      () async {
    final c = _container();
    addTearDown(c.dispose);
    // Force the FutureProvider to resolve so the BoardStack.build observes it.
    await c.read(defaultBoardProvider.future);
    // First read of the stack rebuilds with the resolved default board.
    final stack = c.read(boardStackProvider);
    expect(stack, hasLength(1));
    expect(stack.first.boardId, 'core_main');
  });

  test('push and pop work, depth never drops below 1', () async {
    final c = _container();
    addTearDown(c.dispose);
    await c.read(defaultBoardProvider.future);
    final notifier = c.read(boardStackProvider.notifier);

    notifier.push(subBoardA);
    expect(c.read(boardStackProvider).map((b) => b.boardId),
        ['core_main', 'sub_a']);

    notifier.push(subBoardB);
    expect(c.read(boardStackProvider).map((b) => b.boardId),
        ['core_main', 'sub_a', 'sub_b']);

    notifier.pop();
    expect(c.read(boardStackProvider).map((b) => b.boardId),
        ['core_main', 'sub_a']);

    notifier.pop();
    expect(c.read(boardStackProvider).map((b) => b.boardId), ['core_main']);

    // Pop at root is a no-op.
    notifier.pop();
    expect(c.read(boardStackProvider).map((b) => b.boardId), ['core_main']);
  });

  test('resetToRoot drops everything except the home board', () async {
    final c = _container();
    addTearDown(c.dispose);
    await c.read(defaultBoardProvider.future);
    final notifier = c.read(boardStackProvider.notifier);

    notifier.push(subBoardA);
    notifier.push(subBoardB);
    notifier.resetToRoot();
    expect(c.read(boardStackProvider).map((b) => b.boardId), ['core_main']);
  });

  test('activeBoardProvider reflects the top of the stack', () async {
    final c = _container();
    addTearDown(c.dispose);
    await c.read(defaultBoardProvider.future);

    expect(c.read(activeBoardProvider)?.boardId, 'core_main');
    c.read(boardStackProvider.notifier).push(subBoardA);
    expect(c.read(activeBoardProvider)?.boardId, 'sub_a');
    c.read(boardStackProvider.notifier).pop();
    expect(c.read(activeBoardProvider)?.boardId, 'core_main');
  });
}
