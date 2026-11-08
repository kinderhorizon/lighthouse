/// Settings, Shared boards (ADR 0015 amendment): where a parent who chose
/// "Later" finds a board someone shared, and puts it on the child's board.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_stores.dart';

class _Registry extends BoardRegistry {
  _Registry(this.shared);
  final List<String> shared;
  @override
  List<String> importedBoardIds() => shared;
  @override
  Future<void> removeImported(String boardId) async => shared.remove(boardId);
}

AACBoard _board(String id, String name) => AACBoard(
      schemaVersion: '1.3',
      boardId: id,
      boardName: name,
      gridDimensions: (rows: 1, cols: 2),
      colorKey: const {},
      buttons: const [],
    );

Future<void> _pump(WidgetTester tester,
    {List<String> shared = const [],
    List<CustomButton>? customs,
    FakeCustomButtonStore? store}) async {
  final registry = _Registry(shared);
  final container = ProviderContainer(overrides: [
    boardRegistryProvider.overrideWith((ref) async => registry),
    editableBoardsProvider.overrideWith((ref) async => [
          _board('core_main', 'Home Core'),
          for (final id in shared) _board(id, 'Grandma board'),
        ]),
    ...fakeStoreOverrides(buttons: store ?? FakeCustomButtonStore(customs)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SharedBoardsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{
        'tip_seen.editor': true,
      }));

  testWidgets('with none yet, it says how to get one', (tester) async {
    await _pump(tester);
    expect(find.textContaining('No shared boards yet'), findsOneWidget);
  });

  testWidgets('lists a shared board and puts it on the board', (tester) async {
    await _pump(tester, shared: ['imported_1']);
    expect(find.text('Grandma board'), findsOneWidget);
    expect(find.text('Not on the board yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shared_place_imported_1')));
    await tester.pumpAndSettle();
    final editor = tester.widget<BoardEditScreen>(find.byType(BoardEditScreen));
    expect(editor.rootBoardId, 'core_main');
    expect(editor.placeSharedBoard?.id, 'imported_1');
  });

  testWidgets('says when it is already on the board', (tester) async {
    await _pump(tester, shared: [
      'imported_1'
    ], customs: [
      const CustomButton(
        id: 'c1',
        boardId: 'core_main',
        row: 0,
        col: 0,
        label: 'Grandma board',
        voiceOut: 'Grandma board',
        imagePath: '',
        linkId: 'imported_1',
      ),
    ]);
    expect(find.text('On the board'), findsOneWidget);
  });

  const tile = CustomButton(
    id: 'c1',
    boardId: 'core_main',
    row: 0,
    col: 0,
    label: 'Grandma board',
    voiceOut: 'Grandma board',
    imagePath: '',
    linkId: 'imported_1',
  );

  testWidgets('deletes a shared board and its tile, after asking (ADR 0023)',
      (tester) async {
    final store = FakeCustomButtonStore([tile]);
    await _pump(tester, shared: ['imported_1'], store: store);

    await tester.tap(find.byKey(const ValueKey('shared_delete_imported_1')));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Grandma board"?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shared_delete_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('"Grandma board" was deleted.'), findsOneWidget);
    expect(find.textContaining('No shared boards yet'), findsOneWidget);
    expect(store.items, isEmpty);
  });

  testWidgets('cancel keeps it', (tester) async {
    final store = FakeCustomButtonStore([tile]);
    await _pump(tester, shared: ['imported_1'], store: store);
    await tester.tap(find.byKey(const ValueKey('shared_delete_imported_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shared_delete_cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Grandma board'), findsOneWidget);
    expect(store.items, hasLength(1));
  });
}
