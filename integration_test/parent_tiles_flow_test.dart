/// On-device check of parent-made tiles (ADR 0022), on a simulator / emulator.
/// Boots the full app on REAL storage and walks a parent through every new
/// flow, checking what the child then sees:
///   1. "+ Add" on full Home -> replace "Play" with a yellow category "School";
///   2. open it, add "Pencil" (starts yellow);
///   3. child view: School sits where Play was, opens, Pencil speaks;
///   4. survives an app restart (real files);
///   5. Food: a new button starts orange;
///   6. edit School to green; delete it -> Play is back in its slot;
///   7. "Start this page blank" -> child sees no words; reset brings them back.
/// Run (LH_LOCALE=ar for Arabic). test_driver/ is git-ignored, so use a local
/// driver whose integrationDriver(onScreenshot: ...) saves the PNGs:
///   flutter drive --driver=test_driver/<your screenshot driver>.dart \
///     --target=integration_test/parent_tiles_flow_test.dart -d <device> \
///     --dart-define=LH_LOCALE=en --dart-define=LH_SHOT=<prefix>
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/main.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/persistence/persistence.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/edit/custom_tile_dialog.dart';
import 'package:lighthouse/ui/ui.dart';

const _locale = String.fromEnvironment('LH_LOCALE', defaultValue: 'en');
const _shot = String.fromEnvironment('LH_SHOT', defaultValue: 'dev');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('parent-made tiles: add, replace, categories, colour, blank',
      (tester) async {
    final l10n = lookupAppLocalizations(const Locale(_locale));
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding.completed': true,
      if (_locale != 'en') 'settings.locale_override': _locale,
    });
    final tmp = await Directory.systemTemp.createTemp('lh_parent_tiles_');
    final isar = await IsarSetup.openAt(tmp, name: 'parenttiles');
    final crashStore = CrashLogStore();
    final crashCapture =
        CrashCapture(store: crashStore, deviceInfoSource: DeviceInfoSource());

    Future<void> settle([int ms = 600]) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: ms));
    }

    Future<void> waitFor(Finder f, {int tries = 80}) async {
      for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(f, findsWidgets, reason: 'waited for $f');
    }

    var shots = 0;
    Future<void> shot(String name) async {
      await settle(300);
      shots++;
      await binding.takeScreenshot(
          '${_shot}_${shots.toString().padLeft(2, '0')}_$name');
    }

    Future<void> boot() async {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [
          crashLogStoreProvider.overrideWithValue(crashStore),
          crashCaptureProvider.overrideWithValue(crashCapture),
          isarProvider.overrideWithValue(isar),
        ],
        child: const LighthouseApp(),
      ));
      await settle(1800);
    }

    ProviderContainer container() => ProviderScope.containerOf(
        tester.element(find.byType(LighthouseApp)));

    Future<void> dismissTip() async {
      final g = find.byKey(const ValueKey('tip_gotit'));
      if (g.evaluate().isNotEmpty) {
        await tester.tap(g.first);
        await settle(400);
      }
    }

    Future<void> openEditor() async {
      await tester.tap(find.byIcon(Icons.dashboard_customize_outlined));
      await settle(900);
      await dismissTip();
      final re = RegExp(r'(\d+)\s*\+\s*(\d+)');
      int? a, b;
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final m = re.firstMatch(w.data ?? '');
        if (m != null) {
          a = int.parse(m.group(1)!);
          b = int.parse(m.group(2)!);
          break;
        }
      }
      expect(a, isNotNull, reason: 'math gate equation not found');
      // On a small phone the gate scrolls; reach each key like a parent would.
      for (final ch in (a! + b!).toString().split('')) {
        await tester.ensureVisible(find.byKey(ValueKey('mathkey_$ch')));
        await settle(150);
        await tester.tap(find.byKey(ValueKey('mathkey_$ch')));
        await settle(150);
      }
      await tester.ensureVisible(find.byKey(const ValueKey('mathgate_continue')));
      await settle(200);
      await shot('gate_answered');
      await tester.tap(find.byKey(const ValueKey('mathgate_continue')));
      await settle(1200);
      for (var i = 0;
          i < 80 && find.byKey(const ValueKey('editor_add')).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (find.byKey(const ValueKey('editor_add')).evaluate().isEmpty) {
        await shot('editor_did_not_open');
        debugPrint('VISIBLE TEXT: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => d != null).join(' | ')}');
      }
      await waitFor(find.byKey(const ValueKey('editor_add')));
      await dismissTip();
    }

    Future<void> done() async {
      await tester.tap(find.byKey(const ValueKey('editor_done')));
      await settle(1200);
    }

    Finder childTile(bool Function(AACButton b) test) => find.descendant(
        of: find.byType(AACGrid),
        matching: find.byWidgetPredicate(
            (w) => w is AACButtonTile && test(w.button)));

    Color fillOf(Finder tile) => tester
        .widget<Material>(
            find.descendant(of: tile, matching: find.byType(Material)).first)
        .color!;

    // Bring a child tile fully on screen, as a child would by scrolling (a
    // tile can be built yet half hidden under the "more words" cue).
    Future<void> scrollTo(Finder f) async {
      Finder grid() => find.descendant(
          of: find.byType(AACGrid), matching: find.byType(Scrollable));
      await settle(400);
      if (f.evaluate().isEmpty) {
        // From the top, then down a step at a time, re-finding the grid each
        // time (it can rebuild while the board settles).
        if (grid().evaluate().isNotEmpty) {
          await tester.drag(grid().first, const Offset(0, 4000));
          await settle(300);
        }
        for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
          if (grid().evaluate().isEmpty) {
            await tester.pump(const Duration(milliseconds: 100));
            continue;
          }
          await tester.drag(grid().first, const Offset(0, -180));
          await settle(250);
        }
      }
      if (f.evaluate().isNotEmpty) {
        // Centre it, clear of the bottom "more words" cue.
        await Scrollable.ensureVisible(tester.element(f.first),
            alignment: 0.5);
      }
      await settle(400);
    }

    // Saving writes real files; on a slow emulator that can take a second or
    // two. Wait for the dialog to close rather than a fixed pause.
    Future<void> tapSaveAndWait() async {
      await tester.tap(find.byKey(const ValueKey('custom_tile_save')));
      for (var i = 0;
          i < 100 &&
              find.byKey(const ValueKey('custom_tile_save')).evaluate().isNotEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(CustomTileDialog), findsNothing,
          reason: 'Save must close the dialog');
      await settle(600);
    }

    var keyboardShots = 0;
    Future<void> saveDialog(String text) async {
      await tester.tap(find.byKey(const ValueKey('custom_tile_label')));
      await settle(800);
      await tester.enterText(
          find.byKey(const ValueKey('custom_tile_label')), text);
      await settle(800);
      if (keyboardShots++ == 0) {
        // What a parent sees while typing: Save must stay reachable.
        await shot('typing_keyboard_open');
        final save = tester.getRect(find.byKey(const ValueKey('custom_tile_save')));
        final view = tester.view;
        final visibleBottom = (view.physicalSize.height - view.viewInsets.bottom) /
            view.devicePixelRatio;
        expect(save.bottom, lessThanOrEqualTo(visibleBottom),
            reason: 'Save must stay above the keyboard while typing');
      }
      // The keyboard's Done key, as a parent would press.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(900);
      await tester.ensureVisible(find.byKey(const ValueKey('custom_tile_save')));
      await settle(300);
      await tapSaveAndWait();
    }

    Future<void> pickColour(String name) async {
      final k = find.byKey(ValueKey('tile_color_$name'));
      await tester.ensureVisible(k);
      await settle(200);
      await tester.tap(k);
      await settle(200);
    }

    // ------------------------------------------------------------- start
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await boot();
    // Clean slate on this device (real files persist between runs).
    final c0 = container();
    await c0.read(customButtonsProvider.notifier).resetAll();
    await c0.read(hiddenTilesProvider.notifier).resetAll();
    await c0.read(boardLayoutProvider.notifier).resetAll();
    await c0.read(iconOverridesProvider.notifier).resetAll();
    await c0.read(customVoiceProvider.notifier).resetAll();
    await settle(800);
    await shot('home_before');

    final home = await c0.read(defaultBoardProvider.future);
    final play = home.buttons.firstWhere((b) => b.id == 'btn_play');
    final playLabel = play.labelFor(_locale);

    // ------------------------------------------- 1. replace Play with School
    await openEditor();
    await shot('editor_home');
    await tester.tap(find.byKey(const ValueKey('editor_add')));
    await settle();
    expect(find.text(l10n.editPlaceHintFull), findsOneWidget,
        reason: 'Home is full, so + Add must say so');
    await shot('add_mode_full_page');

    await tester.tap(find.byKey(const ValueKey('editor_tile_btn_play')));
    await settle(900);
    expect(find.text(l10n.replaceDialogTitle(playLabel)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('custom_tile_kind_category')));
    await settle();
    await pickColour('yellow');
    await shot('replace_dialog_category');
    await saveDialog('School');

    final school = container()
        .read(customButtonsProvider)
        .value!
        .singleWhere((b) => b.label == 'School');
    expect(school.isCategory, isTrue);
    expect(school.replacesId, 'btn_play');
    expect(school.tileColor, TileColor.yellow);
    expect(find.byKey(const ValueKey('editor_tile_btn_play')), findsNothing);
    expect(find.byKey(ValueKey('editor_tile_${school.id}')), findsOneWidget);
    await shot('editor_school_in_place_of_play');

    // ------------------------------------------------ 2. open it, add Pencil
    await tester.tap(find.byKey(ValueKey('editor_tile_${school.id}')));
    await settle(900);
    await tester.tap(find.byKey(const ValueKey('sheet_open')));
    await settle(1200);
    await waitFor(find.byKey(const ValueKey('editor_empty_0_0')));
    await shot('editor_school_page_blank');
    await tester.tap(find.byKey(const ValueKey('editor_empty_0_0')));
    await settle(900);
    expect(find.text(l10n.tileColorYellow), findsOneWidget,
        reason: 'a word in a yellow category starts yellow');
    await saveDialog('Pencil');
    final pencil = container()
        .read(customButtonsProvider)
        .value!
        .singleWhere((b) => b.label == 'Pencil');
    expect(pencil.boardId, school.linkId);
    expect(pencil.tileColor, TileColor.yellow);
    await shot('editor_school_page_pencil');
    await tester.tap(find.byKey(const ValueKey('editor_nav_back')));
    await settle(900);
    await done();

    // --------------------------------------------------- 3. the child's view
    final schoolTile = childTile((b) => b.id == school.id);
    await scrollTo(schoolTile);
    expect(schoolTile, findsOneWidget);
    expect(childTile((b) => b.id == 'btn_play'), findsNothing);
    expect(fillOf(schoolTile), const Color(0xFFFFFFA6));
    await shot('child_home_with_school');
    await scrollTo(schoolTile);
    await tester.tap(schoolTile);
    await settle(1200);
    final pencilTile = childTile((b) => b.id == pencil.id);
    await waitFor(pencilTile);
    expect(fillOf(pencilTile), const Color(0xFFFFFFA6));
    await scrollTo(pencilTile);
    await tester.tap(pencilTile);
    await settle(1500);
    await shot('child_after_pencil_tap');
    // The word reached the sentence bar.
    expect(container().read(utteranceProvider).any((t) => t.label == 'Pencil'),
        isTrue);
    // "Return to Home after a word" (on by default) already brought the child
    // back; otherwise go back by hand.
    if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await settle(1200);
    }
    expect(container().read(boardStackProvider).length, 1);

    // --------------------------------------------- 4. survives a restart
    await boot();
    await scrollTo(childTile((b) => b.id == school.id));
    expect(childTile((b) => b.id == school.id), findsOneWidget,
        reason: 'the category must be read back from real files');
    expect(childTile((b) => b.id == 'btn_play'), findsNothing);
    await shot('child_home_after_restart');

    // ------------------------------- 5. Food: a new button starts orange
    await openEditor();
    await tester
        .tap(find.byKey(const ValueKey('editor_folder_btn_food_folder')));
    await settle(1200);
    await tester.tap(find.byKey(const ValueKey('editor_add')));
    await settle();
    expect(find.text(l10n.editPlaceHint), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor_empty_5_7')));
    await settle(900);
    expect(find.text(l10n.tileColorOrange), findsOneWidget,
        reason: 'Food is orange, so a new Food button starts orange');
    await saveDialog('Pizza');
    final pizza = container()
        .read(customButtonsProvider)
        .value!
        .singleWhere((b) => b.label == 'Pizza');
    expect(pizza.tileColor, TileColor.orange);
    await shot('editor_food_with_pizza');
    await tester.tap(find.byKey(const ValueKey('editor_nav_back')));
    await settle(900);

    // ---------------------- 6. edit School to green, then delete it
    await tester.tap(find.byKey(ValueKey('editor_tile_${school.id}')));
    await settle(900);
    await tester.tap(find.byKey(const ValueKey('sheet_edit')));
    await settle(900);
    await pickColour('green');
    await shot('edit_school_green');
    await tapSaveAndWait();
    expect(
        container()
            .read(customButtonsProvider)
            .value!
            .singleWhere((b) => b.id == school.id)
            .tileColor,
        TileColor.green);

    await tester.tap(find.byKey(ValueKey('editor_tile_${school.id}')));
    await settle(900);
    await tester.tap(find.byKey(const ValueKey('sheet_delete')));
    await settle(900);
    expect(find.text(l10n.deleteCategoryConfirm('School', 1)), findsOneWidget);
    await shot('delete_category_confirm');
    await tester.tap(find.byKey(const ValueKey('editor_delete_confirm')));
    await settle(1200);
    await shot('after_delete');
    await waitFor(find.byKey(const ValueKey('editor_tile_btn_play')));
    expect(find.text(l10n.editToastWordBack(playLabel)), findsOneWidget);
    expect(find.byKey(const ValueKey('editor_tile_btn_play')), findsOneWidget);
    expect(
        container()
            .read(customButtonsProvider)
            .value!
            .where((b) => b.id == school.id || b.id == pencil.id),
        isEmpty);
    await shot('editor_play_is_back');
    await settle(2000);

    // ----------------------------- 7. start blank, then reset this board
    await tester.tap(find.byKey(const ValueKey('editor_reset_menu')));
    await settle();
    await tester.tap(find.text(l10n.editStartBlank));
    await settle();
    await tester.tap(find.byKey(const ValueKey('editor_reset_confirm')));
    await settle(1200);
    await shot('editor_blank');
    await done();
    final words = childTile((b) => b.type != AACButtonType.folder);
    expect(words, findsNothing, reason: 'a blank page shows the child no words');
    // Hidden words keep their (blank) places, so the folders stay at the end.
    await scrollTo(childTile((b) => b.id == 'btn_food_folder'));
    expect(childTile((b) => b.id == 'btn_food_folder'), findsOneWidget);
    expect(words, findsNothing);
    await shot('child_home_blank');

    await openEditor();
    await tester.tap(find.byKey(const ValueKey('editor_reset_menu')));
    await settle();
    await tester.tap(find.text(l10n.editResetBoard));
    await settle();
    await tester.tap(find.byKey(const ValueKey('editor_reset_confirm')));
    await settle(1200);
    await done();
    await scrollTo(childTile((b) => b.id == 'btn_play'));
    expect(childTile((b) => b.id == 'btn_play'), findsOneWidget);
    await shot('child_home_reset');
    // Leave the device clean for the next run.
    await container().read(customButtonsProvider.notifier).resetAll();
    await settle(400);
  });
}
