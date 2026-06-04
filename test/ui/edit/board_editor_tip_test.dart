/// Diagnostic: does the editor first-use tip actually appear on first open?
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLayoutStore implements BoardLayoutStore {
  @override
  Future<BoardLayout> load() async => const BoardLayout.empty();
  @override
  Future<void> save(BoardLayout layout) async {}
}

class _FakeFavStore implements FavouritesStore {
  @override
  Future<List<ButtonRef>> pins() async => const [];
  @override
  Future<List<ButtonRef>> pin(ButtonRef ref) async => const [];
  @override
  Future<List<ButtonRef>> unpin(ButtonRef ref) async => const [];
}

class _FakeHiddenStore implements HiddenTilesStore {
  @override
  Future<HiddenTiles> load() async => const HiddenTiles.empty();
  @override
  Future<void> save(HiddenTiles hidden) async {}
}

AACBoard _board() => AACBoard(
      schemaVersion: '1.0',
      boardId: 'core_main',
      boardName: 'Home',
      gridDimensions: (rows: 2, cols: 2),
      colorKey: const {'food': '#FFD9A6'},
      buttons: [
        AACButton(
          id: 'btn_a',
          label: 'A',
          labelByLocale: const {},
          type: AACButtonType.word,
          position: (row: 0, col: 0),
          category: 'food',
          baseWeight: 0.5,
          iconUri: '',
        ),
      ],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('editor first-use tip appears on first open', (tester) async {
    final board = _board();
    final container = ProviderContainer(overrides: [
      editableBoardsProvider.overrideWith((ref) async => [board]),
      defaultBoardProvider.overrideWith((ref) async => board),
      boardLayoutStoreProvider.overrideWithValue(_FakeLayoutStore()),
      favouritesStoreProvider.overrideWithValue(_FakeFavStore()),
      hiddenTilesStoreProvider.overrideWithValue(_FakeHiddenStore()),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        // Disable animations so the editor's infinite jiggle does not hang
        // pumpAndSettle; the tip is opaque at rest, so it still renders.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const BoardEditScreen(rootBoardId: 'core_main'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Editing your board'), findsOneWidget);
    expect(find.byKey(const ValueKey('tip_gotit')), findsOneWidget);
  });

  // Regression: the math-gate dialog tears down AFTER the next screen has shown
  // its tip, and its dismiss() must not remove that newer tip. A dismiss with a
  // different owner key is a no-op; only the owner's own key clears it.
  testWidgets('a foreign-owner dismiss cannot remove a newer tip',
      (tester) async {
    final anchorKey = GlobalKey();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Center(child: SizedBox(key: anchorKey, width: 60, height: 40)),
        ),
      ),
    ));

    final controller = container.read(firstUseTipControllerProvider);
    final prefs = await SharedPreferences.getInstance();
    await controller.maybeShow(
      context: tester.element(find.byType(Scaffold)),
      store: FirstUseTipsStore(prefs: prefs),
      tipKey: FirstUseTipsStore.editorKey,
      anchor: anchorKey,
      title: 'OwnerProbeTitle',
      body: 'body',
      gotItLabel: 'Got it',
      tourActive: false,
      reduceMotion: true,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('OwnerProbeTitle'), findsOneWidget);

    // A late math-gate teardown (different owner) must NOT remove it.
    controller.dismiss(ownerTipKey: FirstUseTipsStore.gateKey);
    await tester.pump();
    expect(find.text('OwnerProbeTitle'), findsOneWidget);

    // The owner's own dismiss clears it.
    controller.dismiss(ownerTipKey: FirstUseTipsStore.editorKey);
    await tester.pump();
    expect(find.text('OwnerProbeTitle'), findsNothing);
  });
}
