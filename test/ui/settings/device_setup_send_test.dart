/// Settings, Copy to another device (ADR 0023): behind the parental gate, it
/// says what goes and what stays, then hands the share sheet one setup file
/// with instructions, and deletes the file afterwards.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/settings/math_gate.dart';
import 'package:lighthouse/ui/settings/settings_primary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localized.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

void main() {
  late Directory tmp;
  late DeviceSetupService service;
  late BoardRegistry registry;
  Map<Object?, Object?>? shared;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tip_seen.gate': true,
    });
    tmp = await Directory.systemTemp.createTemp('setup_send_test_');
    service = DeviceSetupService(
      customButtons: CustomButtonStore(dirOverride: tmp),
      layout: BoardLayoutStore(dirOverride: tmp),
      hidden: HiddenTilesStore(dirOverride: tmp),
      favourites: FavouritesStore(dirOverride: tmp),
      icons: IconOverrideStore(dirOverride: tmp),
      voices: CustomVoiceStore(dirOverride: tmp),
      settings: SettingsRepository(),
      tempDirOverride: tmp,
    );
    registry = BoardRegistry(importedBoardsDirOverride: tmp);
    shared = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
          shared = call.arguments as Map<Object?, Object?>;
          return 'dev.fluttercommunity.plus/share/unavailable';
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
    await tmp.delete(recursive: true);
  });

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
    for (final d in n.reduce((a, b) => a + b).toString().split('')) {
      await tester.tap(find.byKey(ValueKey('mathkey_$d')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
  }

  testWidgets('sends one setup file, says photos stay, then deletes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // A word with a photo: the photo stays on this device.
    await tester.runAsync(() async {
      final photo = File('${tmp.path}/p.png')..writeAsBytesSync([1, 2, 3]);
      final store = CustomButtonStore(dirOverride: tmp);
      final id = await store.allocateId('core_main');
      await store.add(
        CustomButton(
          id: id,
          boardId: 'core_main',
          row: 0,
          col: 0,
          label: 'pizza',
          voiceOut: 'pizza',
          imagePath: await store.importImage(photo, suggestedName: id),
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceSetupServiceProvider.overrideWithValue(service),
          boardRegistryProvider.overrideWith((ref) async => registry),
        ],
        child: localizedApp(const SettingsPrimaryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ANOTHER DEVICE'), findsOneWidget);
    expect(find.text('Copy to another device'), findsOneWidget);
    expect(find.text('Copy from another device'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings_setup_send')));
    await tester.pumpAndSettle();
    await solveGate(tester);
    await settle(tester);

    expect(
      find.textContaining(
        'This makes one file with everything you set '
        'up',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Photos and voice recordings stay on this device. You '
        'can add them again on the other one.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('setup_send_confirm')));
    await settle(tester);

    expect(shared, isNotNull, reason: 'the share sheet was never asked');
    final path = (shared!['paths'] as List).single as String;
    expect(path, endsWith('/Lighthouse setup.json'));
    expect(shared!['text'] as String, contains('Copy from another device'));
    expect(shared!['originWidth'] as num, greaterThan(0));
    expect(File(path).existsSync(), isFalse, reason: 'must not linger');
  });

  testWidgets('Cancel sends nothing and leaves no file', (tester) async {
    tester.view.physicalSize = const Size(1024, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceSetupServiceProvider.overrideWithValue(service),
          boardRegistryProvider.overrideWith((ref) async => registry),
        ],
        child: localizedApp(const SettingsPrimaryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings_setup_send')));
    await tester.pumpAndSettle();
    await solveGate(tester);
    await settle(tester);
    // Nothing to leave behind here, so no note about photos.
    expect(
      find.textContaining('Photos and voice recordings stay'),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('setup_send_cancel')));
    await settle(tester);

    expect(shared, isNull);
    expect(File('${tmp.path}/Lighthouse setup.json').existsSync(), isFalse);
  });
}
