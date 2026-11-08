/// Copying a whole setup from one device to another (ADR 0023), end to end on
/// real stores in two temp folders: what arrives, what is replaced, and what
/// the old setup must not leave behind.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Device {
  _Device(this.dir, SharedPreferences prefs)
    : buttons = CustomButtonStore(dirOverride: dir),
      layout = BoardLayoutStore(dirOverride: dir),
      hidden = HiddenTilesStore(dirOverride: dir),
      favourites = FavouritesStore(dirOverride: dir),
      icons = IconOverrideStore(dirOverride: dir),
      voices = CustomVoiceStore(dirOverride: dir),
      settings = SettingsRepository(prefs: prefs),
      registry = BoardRegistry(importedBoardsDirOverride: dir);

  final Directory dir;
  final CustomButtonStore buttons;
  final BoardLayoutStore layout;
  final HiddenTilesStore hidden;
  final FavouritesStore favourites;
  final IconOverrideStore icons;
  final CustomVoiceStore voices;
  final SettingsRepository settings;
  final BoardRegistry registry;

  DeviceSetupService service() => DeviceSetupService(
    customButtons: buttons,
    layout: layout,
    hidden: hidden,
    favourites: favourites,
    icons: icons,
    voices: voices,
    settings: settings,
    tempDirOverride: dir,
  );

  /// Adds a board as if someone shared it with this device.
  Future<AACBoard> receiveBoard(String name) async {
    final f = File('${dir.path}/in_$name.json')
      ..writeAsStringSync(
        jsonEncode({
          'schema_version': '1.3',
          'board_id': 'core_main',
          'board_name': name,
          'grid_dimensions': [2, 3],
          'color_key': {'food': '#FFD9A6'},
          'tile_color': '#FFD9A6',
          'buttons': [
            {
              'id': 'hug',
              'label': 'hug',
              'type': 'word',
              'position': {'row': 0, 'col': 0},
              'category': 'food',
              'base_weight': 0.5,
              'icon_uri': 'assets/arasaac/hug.png',
              'voice_out': 'hug',
            },
          ],
        }),
      );
    final b = await BoardPackImporter(
      registry: registry,
    ).import(f, assignFreshId: true);
    f.deleteSync();
    return b;
  }
}

File _file(Directory dir, String name) =>
    File('${dir.path}/$name')..writeAsBytesSync([1, 2, 3, 4]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('device_setup_');
  });
  tearDown(() async {
    SharedPreferences.resetStatic();
    await root.delete(recursive: true);
  });

  Future<_Device> device(String name, Map<String, Object> prefs) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues(prefs);
    final d = Directory('${root.path}/$name')..createSync();
    return _Device(d, await SharedPreferences.getInstance());
  }

  test(
    'the whole setup arrives, and the old one is replaced cleanly',
    () async {
      // ---- The sending tablet.
      final a = await device('a', {
        'settings.glow_style': 'dot',
        'settings.locale_override': 'es',
      });
      final sharedA = await a.receiveBoard('Grandma board');
      expect(sharedA.boardId, 'imported_1');
      final pizzaId = await a.buttons.allocateId('core_main');
      final pizzaPhoto = await a.buttons.importImage(
        _file(a.dir, 'pizza.png'),
        suggestedName: pizzaId,
      );
      await a.buttons.add(
        CustomButton(
          id: pizzaId,
          boardId: 'core_main',
          row: 6,
          col: 7,
          label: 'pizza',
          voiceOut: 'pizza',
          imagePath: pizzaPhoto,
          replacesId: 'stop',
        ),
      );
      final familyId = await a.buttons.allocateId('core_main');
      final page = await a.buttons.allocateCategoryBoardId();
      await a.buttons.add(
        CustomButton(
          id: familyId,
          boardId: 'core_main',
          row: 6,
          col: 6,
          label: 'Family',
          voiceOut: 'Family',
          imagePath: '',
          linkId: page,
          tileColor: TileColor.pink,
        ),
      );
      final grandmaId = await a.buttons.allocateId(page);
      await a.buttons.add(
        CustomButton(
          id: grandmaId,
          boardId: page,
          row: 0,
          col: 0,
          label: 'Grandma',
          voiceOut: 'Grandma',
          imagePath: '',
        ),
      );
      final tileId = await a.buttons.allocateId('core_main');
      await a.buttons.add(
        CustomButton(
          id: tileId,
          boardId: 'core_main',
          row: 6,
          col: 5,
          label: 'Grandma board',
          voiceOut: 'Grandma board',
          imagePath: '',
          linkId: sharedA.boardId,
        ),
      );
      await a.layout.save(
        BoardLayout.fromJson({
          'core_main': {
            familyId: {'row': 1, 'col': 1},
          },
        }),
      );
      await a.hidden.save(
        HiddenTiles.fromJson({
          'board_food': ['apple'],
        }),
      );
      await a.favourites.pin((boardId: 'core_main', buttonId: pizzaId));
      await a.favourites.pin((
        boardId: 'imported_1',
        buttonId: 'imported_1__hug',
      ));
      await a.voices.importClip(_file(a.dir, 'v.m4a'), buttonId: pizzaId);

      final export = await a.service().prepare(
        a.registry,
        fileBaseName: 'Lighthouse setup',
      );
      expect(export.file.path, endsWith('/Lighthouse setup.json'));
      expect(export.photosLeftBehind, 1);
      expect(export.recordingsLeftBehind, 1);
      final sentText = export.file.readAsStringSync();
      expect(sentText, isNot(contains('pizza.png')));
      expect(sentText, isNot(contains(a.dir.path)));

      // ---- The receiving tablet, with a setup of its own.
      final b = await device('b', {'settings.glow_style': 'halo'});
      final sharedB = await b.receiveBoard('Old board');
      expect(sharedB.boardId, 'imported_1', reason: 'same id as the sender');
      for (var i = 0; i < 3; i++) {
        await b.buttons.allocateId('core_main');
      }
      final oldPhoto = await b.buttons.importImage(
        _file(b.dir, 'grandpa.png'),
        suggestedName: 'custom_core_main_2',
      );
      await b.buttons.add(
        CustomButton(
          id: 'custom_core_main_2',
          boardId: 'core_main',
          row: 6,
          col: 7,
          label: 'grandpa',
          voiceOut: 'grandpa',
          imagePath: oldPhoto,
        ),
      );
      await b.voices.importClip(_file(b.dir, 'w.m4a'), buttonId: 'want');
      await b.voices.importClip(
        _file(b.dir, 'g.m4a'),
        buttonId: 'custom_core_main_2',
      );
      await b.voices.importClip(
        _file(b.dir, 'h.m4a'),
        buttonId: 'imported_1__hug',
      );
      await b.icons.setImage(
        _file(b.dir, 'eat.png'),
        boardId: 'core_main',
        buttonId: 'eat',
      );
      await b.icons.setImage(
        _file(b.dir, 'gp.png'),
        boardId: 'core_main',
        buttonId: 'custom_core_main_2',
      );

      final setup = (await DeviceSetup.readFile(export.file))!;
      await b.service().apply(setup, b.registry);

      // The sender's words, with new ids from this device's marks, no photos.
      final now = await b.buttons.load();
      expect(now.map((c) => c.label), [
        'pizza',
        'Family',
        'Grandma',
        'Grandma board',
      ]);
      final byLabel = {for (final c in now) c.label: c};
      expect(byLabel['pizza']!.id, 'custom_core_main_3');
      expect(byLabel['pizza']!.imagePath, isEmpty);
      expect(byLabel['pizza']!.replacesId, 'stop');
      expect(byLabel['Family']!.tileColor, TileColor.pink);
      expect(byLabel['Family']!.linkId, 'cat_0');
      expect(byLabel['Grandma']!.boardId, 'cat_0');
      expect(byLabel['Grandma board']!.linkId, 'imported_2');
      final marks = await b.buttons.counters();
      expect(marks['core_main'], 6);

      // The shared board came over under a new id; the old one is gone.
      expect(b.registry.importedBoardIds(), ['imported_2']);
      expect(
        File('${b.dir.path}/imported_boards/imported_1.json').existsSync(),
        isFalse,
      );
      final fresh = BoardRegistry(importedBoardsDirOverride: b.dir);
      await fresh.hydrate();
      expect(fresh.importedBoardIds(), ['imported_2']);
      final arrived = await fresh.tryLoad('imported_2');
      expect(arrived!.boardName, 'Grandma board');
      expect(arrived.buttons.single.id, 'imported_2__hug');
      expect(arrived.tileColor, TileColor.orange);
      expect(
        await fresh.allocateImportedBoardId(),
        'imported_3',
        reason: 'a deleted shared board id is never handed out again',
      );

      // Pins, arrangement, hidden words and settings.
      expect(await b.favourites.pins(), [
        (boardId: 'core_main', buttonId: 'custom_core_main_3'),
        (boardId: 'imported_2', buttonId: 'imported_2__hug'),
      ]);
      expect(
        (await b.layout.load()).positionOf('core_main', 'custom_core_main_4'),
        (row: 1, col: 1),
      );
      expect((await b.hidden.load()).isHidden('board_food', 'apple'), isTrue);
      final settings = await b.settings.read();
      expect(settings.glowStyle, GlowStyle.dot);
      expect(settings.localeOverride, 'es');

      // What the old setup leaves behind is gone; built-in words keep theirs.
      expect(File(oldPhoto).existsSync(), isFalse);
      expect((await b.voices.load()).keys, ['want']);
      expect((await b.icons.load()).keys, [
        IconOverrideStore.key('core_main', 'eat'),
      ]);
    },
  );

  test('an unreadable custom button store is never overwritten', () async {
    final b = await device('b', {});
    File(
      '${b.dir.path}/${CustomButtonStore.fileName}',
    ).writeAsStringSync('{broken');
    final setup = DeviceSetup.fromJson({DeviceSetup.marker: 1});
    await expectLater(
      b.service().apply(setup, b.registry),
      throwsA(isA<CustomButtonStoreReadException>()),
    );
    expect(
      File('${b.dir.path}/${CustomButtonStore.fileName}').readAsStringSync(),
      '{broken',
    );
  });
}
