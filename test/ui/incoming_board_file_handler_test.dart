/// A board file the phone hands to Lighthouse ("Open with Lighthouse", ADR
/// 0015 amendment) is offered to the parent, gated, imported as a new board,
/// and its temporary copy is always deleted.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('test/incoming_file');

Map<String, Object?> _boardJson(String name) => {
  'schema_version': '1.3',
  'board_id': 'core_main',
  'board_name': name,
  'grid_dimensions': [1, 2],
  'color_key': {'food': '#FFD9A6'},
  'buttons': [
    {
      'id': 'apple',
      'label': 'apple',
      'type': 'word',
      'position': {'row': 0, 'col': 0},
      'category': 'food',
      'base_weight': 0.5,
      'icon_uri': '',
      'voice_out': 'apple',
    },
  ],
};

void main() {
  late Directory tmp;
  late BoardRegistry registry;
  String? pending;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tip_seen.gate': true,
    });
    tmp = await Directory.systemTemp.createTemp('incoming_board_test_');
    registry = BoardRegistry(
      importedBoardsDirOverride: Directory('${tmp.path}/support'),
    );
    pending = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method != 'takePendingFile') return null;
          final p = pending;
          pending = null;
          return p;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await tmp.delete(recursive: true);
  });

  File writeIncoming(String contents) {
    final f = File(
      '${tmp.path}/board_incoming_${DateTime.now().microsecondsSinceEpoch}.json',
    )..writeAsStringSync(contents);
    pending = f.path;
    return f;
  }

  Future<void> pumpHost(WidgetTester tester) async {
    // An iPad-sized screen, so the whole math gate (keypad + Continue) fits.
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incomingBoardFilesProvider.overrideWithValue(
            IncomingBoardFiles(channel: _channel),
          ),
          boardRegistryProvider.overrideWith((ref) async => registry),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: IncomingBoardFileHandler(
            child: Scaffold(body: Text('the board')),
          ),
        ),
      ),
    );
  }

  /// Lets the real file IO in the handler finish, then settles the UI. Each
  /// awaited IO step needs real time AND a pump (its continuation is queued in
  /// the test's fake-async zone), and an import is a chain of several.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> solveGate(WidgetTester tester) async {
    expect(find.byType(MathGate), findsOneWidget);
    final eq = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(MathGate),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .firstWhere((s) => RegExp(r'^\d+ \+ \d+ = \?$').hasMatch(s));
    final n = RegExp(r'\d+').allMatches(eq).map((m) => int.parse(m[0]!));
    final answer = n.reduce((a, b) => a + b).toString();
    for (final d in answer.split('')) {
      await tester.tap(find.byKey(ValueKey('mathkey_$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
  }

  testWidgets('a board that opened the app is offered, gated and imported', (
    tester,
  ) async {
    final file = writeIncoming(jsonEncode(_boardJson('Grandma board')));
    await pumpHost(tester);
    await settle(tester);

    expect(find.text('Add a shared board?'), findsOneWidget);
    expect(find.textContaining('"Grandma board"'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('incoming_board_add')));
    await tester.pumpAndSettle();

    await solveGate(tester);
    await settle(tester);

    expect(find.text('Imported "Grandma board".'), findsOneWidget);
    // A new, separate board: re-ided, the sender's own id is not reused.
    expect(registry.knows('imported_1'), isTrue);
    final imported = await tester.runAsync(
      () => registry.tryLoad('imported_1'),
    );
    expect(imported?.boardName, 'Grandma board');
    expect(file.existsSync(), isFalse, reason: 'the copy must not linger');
  });

  testWidgets('a file arriving while the app runs is offered too', (
    tester,
  ) async {
    await pumpHost(tester);
    await settle(tester);
    expect(find.text('Add a shared board?'), findsNothing);

    writeIncoming(jsonEncode(_boardJson('Sent later')));
    await tester.runAsync(() async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            _channel.codec.encodeMethodCall(const MethodCall('fileReceived')),
            (_) {},
          );
    });
    await settle(tester);

    expect(find.textContaining('"Sent later"'), findsOneWidget);
  });

  testWidgets('Cancel adds nothing and deletes the copy', (tester) async {
    final file = writeIncoming(jsonEncode(_boardJson('No thanks')));
    await pumpHost(tester);
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('incoming_board_cancel')));
    await settle(tester);

    expect(find.byType(MathGate), findsNothing);
    expect(registry.knows('imported_1'), isFalse);
    expect(file.existsSync(), isFalse);
  });

  testWidgets(
    'leaving the math gate adds nothing (a child cannot add boards)',
    (tester) async {
      final file = writeIncoming(jsonEncode(_boardJson('Gated')));
      await pumpHost(tester);
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('incoming_board_add')));
      await tester.pumpAndSettle();
      expect(find.byType(MathGate), findsOneWidget);
      await tester.tapAt(const Offset(4, 4)); // outside the gate dialog
      await settle(tester);

      expect(find.byType(MathGate), findsNothing);
      expect(registry.knows('imported_1'), isFalse);
      expect(file.existsSync(), isFalse);
    },
  );

  testWidgets('a file that is not a board gets a plain answer, no gate', (
    tester,
  ) async {
    final file = writeIncoming('{"hello": "not a board"}');
    await pumpHost(tester);
    await settle(tester);

    expect(find.text('Add a shared board?'), findsNothing);
    expect(find.byType(MathGate), findsNothing);
    expect(
      find.text('That file is not a Lighthouse board, so nothing was added.'),
      findsOneWidget,
    );
    expect(file.existsSync(), isFalse);
  });

  testWidgets('no native side (desktop, older builds): nothing happens', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await pumpHost(tester);
    await settle(tester);
    expect(find.text('the board'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
