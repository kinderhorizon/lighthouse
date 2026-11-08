/// A setup copied to another device (ADR 0023): the file's contract, what an
/// untrusted file is allowed to carry, and how every parent-made id is made
/// fresh on the receiving device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';

AACButton _word(String id, int row, int col, {String category = 'food'}) =>
    AACButton(
      id: id,
      label: id,
      labelByLocale: const {},
      type: AACButtonType.word,
      position: (row: row, col: col),
      category: category,
      baseWeight: 0.5,
      iconUri: 'assets/arasaac/$id.png',
      voiceOut: id,
    );

AACBoard _sharedBoard(String id) => AACBoard(
  schemaVersion: '1.3',
  boardId: id,
  boardName: 'Grandma board',
  gridDimensions: (rows: 2, cols: 3),
  colorKey: const {'food': '#FFD9A6'},
  buttons: [_word('${id}__hug', 0, 0), _word('${id}__cake', 0, 1)],
  tileColor: TileColor.orange,
);

CustomButton _custom(
  String id,
  String boardId, {
  String label = 'pizza',
  String? linkId,
  String? replacesId,
  String imagePath = '',
  int row = 0,
  int col = 0,
}) => CustomButton(
  id: id,
  boardId: boardId,
  row: row,
  col: col,
  label: label,
  voiceOut: label,
  imagePath: imagePath,
  linkId: linkId,
  replacesId: replacesId,
  tileColor: TileColor.orange,
);

/// What a parent set up on the sending tablet: a word on Home that replaced
/// "stop", a category "Family" on Home with "Grandma" inside, a word added to
/// Food, a shared board with its tile on Home and a word added on it, plus
/// pins, hidden words and a moved tile that refer to all of these.
DeviceSetup _sent() => DeviceSetup(
  settings: const SetupSettings(
    glowStyle: GlowStyle.dot,
    hasLocale: true,
    localeOverride: 'es',
    hideTileText: true,
  ),
  customButtons: [
    _custom(
      'custom_core_main_0',
      'core_main',
      label: 'pizza',
      replacesId: 'stop',
      imagePath: '/a/pizza.jpg',
    ),
    _custom(
      'custom_core_main_1',
      'core_main',
      label: 'Family',
      linkId: 'cat_0',
      row: 2,
    ),
    _custom('custom_cat_0_0', 'cat_0', label: 'Grandma'),
    _custom('custom_board_food_0', 'board_food', label: 'samosa'),
    _custom(
      'custom_core_main_2',
      'core_main',
      label: 'Grandma board',
      linkId: 'imported_3',
      row: 3,
    ),
    _custom('custom_imported_3_0', 'imported_3', label: 'nap', row: 1),
  ],
  layout: BoardLayout.fromJson({
    'core_main': {
      'custom_core_main_1': {'row': 4, 'col': 4},
      'want': {'row': 5, 'col': 5},
    },
    'imported_3': {
      'imported_3__cake': {'row': 1, 'col': 2},
    },
  }),
  hidden: HiddenTiles.fromJson({
    'cat_0': ['custom_cat_0_0'],
    'board_food': ['apple'],
    'imported_3': ['imported_3__hug'],
  }),
  pins: const [
    (boardId: 'core_main', buttonId: 'custom_core_main_0'),
    (boardId: 'imported_3', buttonId: 'imported_3__cake'),
    (boardId: 'core_main', buttonId: 'want'),
  ],
  sharedBoards: [_sharedBoard('imported_3')],
);

const _bundled = {'core_main', 'board_food', 'board_people'};

Future<PreparedSetup> _prepare(
  DeviceSetup setup, {
  Map<String, int> counters = const {},
}) {
  var n = 7;
  return prepareForDevice(
    setup,
    counters: counters,
    bundledBoardIds: _bundled,
    newSharedBoardId: () async => 'imported_${n++}',
  );
}

void main() {
  group('the file', () {
    test('carries exactly its contracted keys, never a photo path', () {
      final json = _sent().toJson();
      expect(json.keys.toSet(), {
        DeviceSetup.marker,
        'settings',
        'custom_buttons',
        'layout',
        'hidden',
        'pins',
        'shared_boards',
      });
      expect(json[DeviceSetup.marker], DeviceSetup.formatVersion);
      for (final b in json['custom_buttons'] as List) {
        expect((b as Map)['image_path'], '');
      }
      final text = jsonEncode(json);
      expect(text, isNot(contains('/a/pizza.jpg')));
      // No learning or usage ever travels.
      for (final word in ['alpha', 'beta', 'observation', 'tap', 'state_key']) {
        expect(text.toLowerCase(), isNot(contains(word)));
      }
    });

    test('reads back what it wrote', () {
      final back = DeviceSetup.fromJson(
        jsonDecode(jsonEncode(_sent().toJson())) as Map<String, dynamic>,
      );
      expect(back.customButtons.map((c) => c.label), [
        'pizza',
        'Family',
        'Grandma',
        'samosa',
        'Grandma board',
        'nap',
      ]);
      expect(back.customButtons.first.replacesId, 'stop');
      expect(back.customButtons.first.imagePath, '');
      expect(back.sharedBoards.single.tileColor, TileColor.orange);
      expect(back.pins, hasLength(3));
      expect(back.layout.positionOf('core_main', 'want'), (row: 5, col: 5));
      expect(back.hidden.isHidden('board_food', 'apple'), isTrue);
      expect(back.settings.glowStyle, GlowStyle.dot);
      expect(back.settings.hasLocale, isTrue);
      expect(back.settings.localeOverride, 'es');
      expect(back.settings.hideTileText, isTrue);
    });

    test(
      'a newer format is refused; a file without the marker is not a setup',
      () {
        expect(
          () => DeviceSetup.fromJson({DeviceSetup.marker: 2}),
          throwsA(isA<DeviceSetupTooNewException>()),
        );
        expect(DeviceSetup.isSetup({'board_id': 'core_main'}), isFalse);
        expect(DeviceSetup.isSetup({DeviceSetup.marker: 1}), isTrue);
      },
    );

    test('readFile: null for a single board, a setup for a setup', () async {
      final dir = await Directory.systemTemp.createTemp('setup_read_');
      addTearDown(() => dir.delete(recursive: true));
      final board = File('${dir.path}/b.json')
        ..writeAsStringSync(jsonEncode(_sharedBoard('imported_1').toJson()));
      final setup = File('${dir.path}/s.json')
        ..writeAsStringSync(jsonEncode(_sent().toJson()));
      final junk = File('${dir.path}/j.json')..writeAsStringSync('not json');
      expect(await DeviceSetup.readFile(board), isNull);
      expect((await DeviceSetup.readFile(setup))!.customButtons, hasLength(6));
      expect(
        () => DeviceSetup.readFile(junk),
        throwsA(isA<DeviceSetupException>()),
      );
    });

    test('an untrusted file: bad parts are left out, not trusted', () {
      final setup = DeviceSetup.fromJson({
        DeviceSetup.marker: 1,
        'settings': {
          'glow_style': 'sparkles',
          'locale': 'xx',
          'hide_tile_text': true,
          'hide_pictogram': true,
        },
        'custom_buttons': [
          {
            'id': 'ok',
            'board_id': 'core_main',
            'row': 0,
            'col': 0,
            'label': 'ok',
            'image_path': '/var/mobile/secret.jpg',
          },
          {'id': 'a|b', 'board_id': 'core_main', 'row': 0, 'col': 1},
          {'id': 'x', 'board_id': '../../etc', 'row': 0, 'col': 1},
          {'id': 'y', 'board_id': 'core_main', 'row': 999, 'col': 1},
          {'id': 'ok', 'board_id': 'core_main', 'row': 1, 'col': 1},
          'nonsense',
        ],
        'shared_boards': [
          {'board_id': 'bad', 'buttons': 'nope'},
          {
            ..._sharedBoard('imported_2').toJson(),
            'buttons': [
              {..._word('h', 0, 0).toJson(), 'icon_uri': '/private/photo.jpg'},
            ],
          },
        ],
        'pins': [
          {'board_id': 'core_main', 'button_id': 'a:b'},
          {'board_id': 'core_main', 'button_id': 'want'},
        ],
        'layout': 'nope',
      });
      expect(setup.customButtons.map((c) => c.id), ['ok']);
      expect(setup.customButtons.single.imagePath, '');
      expect(setup.sharedBoards.single.buttons.single.iconUri, '');
      expect(setup.pins, [(boardId: 'core_main', buttonId: 'want')]);
      expect(setup.layout.isEmpty, isTrue);
      expect(setup.settings.glowStyle, isNull);
      expect(setup.settings.hasLocale, isFalse);
      // Never both hidden: a blank tile is unusable.
      expect(setup.settings.hideTileText, isTrue);
      expect(setup.settings.hidePictogram, isFalse);
    });
  });

  group('on the receiving device', () {
    test(
      'every parent-made word, page and shared board gets a fresh id',
      () async {
        final p = await _prepare(
          _sent(),
          counters: {
            'core_main': 4,
            'board_food': 2,
            CustomButtonStore.categoryCounterKey: 5,
          },
        );
        final byLabel = {for (final c in p.customButtons) c.label: c};

        // Numbered from this device's marks, never from the sender's.
        expect(byLabel['pizza']!.id, 'custom_core_main_4');
        expect(byLabel['Family']!.id, 'custom_core_main_5');
        expect(byLabel['Grandma board']!.id, 'custom_core_main_6');
        expect(byLabel['samosa']!.id, 'custom_board_food_2');
        // The category page is new here, and so is the shared board.
        expect(byLabel['Family']!.linkId, 'cat_5');
        expect(byLabel['Grandma']!.boardId, 'cat_5');
        expect(byLabel['Grandma']!.id, 'custom_cat_5_0');
        expect(byLabel['Grandma board']!.linkId, 'imported_7');
        expect(byLabel['nap']!.boardId, 'imported_7');
        expect(byLabel['nap']!.id, 'custom_imported_7_0');
        // Built-in words keep their ids; colours come along; photos do not.
        expect(byLabel['pizza']!.replacesId, 'stop');
        expect(byLabel['pizza']!.tileColor, TileColor.orange);
        expect(p.customButtons.every((c) => c.imagePath.isEmpty), isTrue);

        expect(p.counters, {
          'core_main': 7,
          'board_food': 3,
          'cat_5': 1,
          'imported_7': 1,
          CustomButtonStore.categoryCounterKey: 6,
        });

        final shared = p.sharedBoards.single;
        expect(shared.boardId, 'imported_7');
        expect(shared.buttons.map((b) => b.id), [
          'imported_7__hug',
          'imported_7__cake',
        ]);
        expect(shared.tileColor, TileColor.orange);
      },
    );

    test('pins, arrangement and hidden words follow the new ids', () async {
      final p = await _prepare(_sent(), counters: {'core_main': 4});
      expect(p.pins, [
        (boardId: 'core_main', buttonId: 'custom_core_main_4'),
        (boardId: 'imported_7', buttonId: 'imported_7__cake'),
        (boardId: 'core_main', buttonId: 'want'),
      ]);
      expect(p.layout.positionOf('core_main', 'custom_core_main_5'), (
        row: 4,
        col: 4,
      ));
      expect(p.layout.positionOf('core_main', 'want'), (row: 5, col: 5));
      expect(p.layout.positionOf('imported_7', 'imported_7__cake'), (
        row: 1,
        col: 2,
      ));
      expect(
        p.hidden.isHidden('cat_0', 'custom_cat_0_0'),
        isTrue,
        reason: 'cat_0 is unused here: counters start at 0',
      );
      expect(p.hidden.isHidden('board_food', 'apple'), isTrue);
      expect(p.hidden.isHidden('imported_7', 'imported_7__hug'), isTrue);
    });

    test(
      'anything that points at what the file does not bring is left out',
      () async {
        final setup = DeviceSetup(
          settings: const SetupSettings(),
          customButtons: [
            // On a board this device does not have.
            _custom('custom_board_space_0', 'board_space'),
            // A tile that opens a shared board the file does not carry.
            _custom('custom_core_main_0', 'core_main', linkId: 'imported_9'),
            // A word on a category page no folder opens.
            _custom('custom_cat_4_0', 'cat_4'),
            _custom('custom_core_main_1', 'core_main', label: 'kept'),
          ],
          layout: BoardLayout.fromJson({
            'core_main': {
              'custom_core_main_0': {'row': 1, 'col': 1},
              'custom_core_main_8': {'row': 1, 'col': 2},
            },
            'imported_9': {
              'x': {'row': 0, 'col': 0},
            },
          }),
          hidden: const HiddenTiles.empty(),
          pins: const [
            (boardId: 'core_main', buttonId: 'custom_core_main_9'),
            (boardId: 'cat_4', buttonId: 'custom_cat_4_0'),
          ],
          // A shared board posing as a built-in one.
          sharedBoards: [_sharedBoard('core_main')],
        );
        final p = await _prepare(setup);
        expect(p.customButtons.map((c) => c.label), ['kept']);
        expect(p.customButtons.single.id, 'custom_core_main_0');
        expect(p.sharedBoards, isEmpty);
        expect(p.pins, isEmpty);
        // The sender's custom_core_main_0 did not come over: its old position
        // must not wait here for the word that now has that id.
        expect(p.layout.forBoard('core_main'), isEmpty);
        expect(p.layout.forBoard('imported_9'), isEmpty);
      },
    );
  });
}
