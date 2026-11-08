/// A child's whole setup as one file, for copying it to another device
/// (ADR 0023).
///
/// What travels: the parent's own words and categories (with their colours),
/// where tiles are, hidden words, pinned words, shared boards and the app
/// settings. What does not: photos, voice recordings and the learned word
/// weights. Photos and recordings never leave the device (ADR 0015, privacy
/// page), and learning stays with the device it happened on.
///
/// The file is untrusted on the receiving side (anyone can hand a parent a
/// file), so [DeviceSetup.fromJson] checks every part and drops what it cannot
/// use, and [prepareForDevice] gives every parent-made word, category page and
/// shared board a FRESH id on the receiving device. Ids there are never reused
/// (ADR 0014, ADR 0022): taking the sender's ids could hand an old word's
/// learning, recording or picture on this device to a different word.
library;

import 'dart:convert';
import 'dart:io';

import '../../i18n/locale_registry.dart';
import '../../logic/favourites/favourite_ranking.dart';
import '../../models/models.dart';
import '../board_loader.dart';
import '../board_pack_importer.dart';
import '../custom/custom_button_store.dart';
import '../settings/settings_repository.dart';

/// A file that cannot be used as a setup. Nothing has been changed when this
/// is thrown.
class DeviceSetupException implements Exception {
  const DeviceSetupException(this.message);
  final String message;
  @override
  String toString() => 'DeviceSetupException: $message';
}

/// The setup was made by a newer Lighthouse that writes a format this version
/// does not know. The parent is asked to update the app.
class DeviceSetupTooNewException extends DeviceSetupException {
  const DeviceSetupTooNewException() : super('made by a newer version');
}

/// The app settings that travel with a setup. Each is null when the file does
/// not carry it, and that setting is then left as it is on the receiving
/// device. [hasLocale] tells "follow the system language" (true with a null
/// [localeOverride]) apart from "not in the file" (false).
class SetupSettings {
  const SetupSettings({
    this.ttsMode,
    this.glowStyle,
    this.hitboxMagnitude,
    this.hasLocale = false,
    this.localeOverride,
    this.autoReturnToHome,
    this.hideTileText,
    this.hidePictogram,
  });

  factory SetupSettings.of(SettingsState s) => SetupSettings(
    ttsMode: s.ttsMode,
    glowStyle: s.glowStyle,
    hitboxMagnitude: s.hitboxMagnitude,
    hasLocale: true,
    localeOverride: s.localeOverride,
    autoReturnToHome: s.autoReturnToHome,
    hideTileText: s.hideTileText,
    hidePictogram: s.hidePictogram,
  );

  final TtsMode? ttsMode;
  final GlowStyle? glowStyle;
  final HitboxMagnitude? hitboxMagnitude;
  final bool hasLocale;
  final String? localeOverride;
  final bool? autoReturnToHome;
  final bool? hideTileText;
  final bool? hidePictogram;

  Map<String, dynamic> toJson() => {
    if (ttsMode != null) 'tts_mode': ttsMode!.toJson(),
    if (glowStyle != null) 'glow_style': glowStyle!.toJson(),
    if (hitboxMagnitude != null) 'hitbox': hitboxMagnitude!.toJson(),
    if (hasLocale) 'locale': localeOverride,
    if (autoReturnToHome != null) 'auto_return_to_home': autoReturnToHome,
    if (hideTileText != null) 'hide_tile_text': hideTileText,
    if (hidePictogram != null) 'hide_pictogram': hidePictogram,
  };

  /// Keeps only values this version knows; anything else is left out (that
  /// setting stays as it is). Tile text and pictures are never both hidden: a
  /// blank tile is unusable, so the pictures win.
  factory SetupSettings.fromJson(Object? raw) {
    if (raw is! Map) return const SetupSettings();
    bool? flag(String key) => raw[key] is bool ? raw[key] as bool : null;
    final locale = raw['locale'];
    final knownLocale =
        locale is String && LocaleRegistry.specForCode(locale) != null;
    final hideText = flag('hide_tile_text');
    var hidePictures = flag('hide_pictogram');
    if (hideText == true && hidePictures == true) hidePictures = false;
    return SetupSettings(
      ttsMode: TtsMode.tryParse(_string(raw['tts_mode'])),
      glowStyle: GlowStyle.tryParse(_string(raw['glow_style'])),
      hitboxMagnitude: HitboxMagnitude.tryParse(_string(raw['hitbox'])),
      hasLocale: raw.containsKey('locale') && (locale == null || knownLocale),
      localeOverride: knownLocale ? locale : null,
      autoReturnToHome: flag('auto_return_to_home'),
      hideTileText: hideText,
      hidePictogram: hidePictures,
    );
  }

  static String? _string(Object? v) => v is String ? v : null;
}

class DeviceSetup {
  const DeviceSetup({
    required this.settings,
    required this.customButtons,
    required this.layout,
    required this.hidden,
    required this.pins,
    required this.sharedBoards,
  });

  /// Top-level key that marks a setup file (a single shared board has none),
  /// holding the format version.
  static const String marker = 'lighthouse_setup';

  /// The format this version writes and the newest it reads.
  static const int formatVersion = 1;

  /// Sanity caps for an untrusted file. Real setups are far below them.
  static const int maxCustomButtons = 5000;
  static const int maxSharedBoards = 200;
  static const int maxPins = 500;

  /// Longest button id a shared board may carry here. Re-iding on the
  /// receiving device makes an id a few characters longer, which must stay
  /// under the button id cap ([kMaxButtonTextLength]).
  static const int _maxSharedButtonIdLength = kMaxButtonTextLength - 128;

  final SetupSettings settings;

  /// The parent's own words and category folders. Never with a photo.
  final List<CustomButton> customButtons;
  final BoardLayout layout;
  final HiddenTiles hidden;
  final List<ButtonRef> pins;

  /// Boards someone shared, as added on the sending device.
  final List<AACBoard> sharedBoards;

  /// Exactly the keys below, nothing else (the contract test pins this, like
  /// the shared-board key-set test): no learning, no usage, no device paths.
  Map<String, dynamic> toJson() => {
    marker: formatVersion,
    'settings': settings.toJson(),
    'custom_buttons': [
      for (final b in customButtons) b.withImagePath('').toJson(),
    ],
    'layout': layout.toJson(),
    'hidden': hidden.toJson(),
    'pins': [
      for (final p in pins) {'board_id': p.boardId, 'button_id': p.buttonId},
    ],
    'shared_boards': [
      for (final b in sharedBoards)
        b.copyWithButtons([
          for (final x in b.buttons)
            x.withIconUri(BoardPackImporter.safeImportedIconUri(x.iconUri)),
        ]).toJson(),
    ],
  };

  /// True when [json] is a setup (it has the [marker] key), as opposed to a
  /// single shared board.
  static bool isSetup(Object? json) => json is Map && json.containsKey(marker);

  /// Reads a setup from an untrusted file. Returns null when the file is JSON
  /// but not a setup (most likely a single shared board), so the caller can
  /// treat it as one. Throws [DeviceSetupException] when it cannot be read or
  /// is a setup this version cannot use.
  static Future<DeviceSetup?> readFile(File file) async {
    final Object? json;
    try {
      if (await file.length() > BoardLoader.maxFileBytes) {
        throw const DeviceSetupException('file too large');
      }
      json = jsonDecode(await file.readAsString());
    } on DeviceSetupException {
      rethrow;
    } catch (e) {
      throw DeviceSetupException('could not read the file: $e');
    }
    if (!isSetup(json)) return null;
    return DeviceSetup.fromJson(Map<String, dynamic>.from(json as Map));
  }

  /// Checks every part of an untrusted setup and keeps what is safe to use.
  /// A part that is missing or malformed is left out rather than failing the
  /// whole file; only an unknown format fails it.
  factory DeviceSetup.fromJson(Map<String, dynamic> json) {
    final version = json[marker];
    if (version is! int || version < 1) {
      throw const DeviceSetupException('not a Lighthouse setup');
    }
    if (version > formatVersion) throw const DeviceSetupTooNewException();

    final customs = <CustomButton>[];
    final seenIds = <String>{};
    final rawCustoms = json['custom_buttons'];
    if (rawCustoms is List) {
      for (final e in rawCustoms.take(maxCustomButtons)) {
        if (e is! Map) continue;
        final CustomButton c;
        try {
          c = CustomButton.fromJson(Map<String, dynamic>.from(e));
        } catch (_) {
          continue;
        }
        if (!_isSafeId(c.id) ||
            !AACBoard.isValidBoardId(c.boardId) ||
            c.row < 0 ||
            c.col < 0 ||
            c.row >= kMaxGridSide ||
            c.col >= kMaxGridSide ||
            c.label.length > kMaxButtonTextLength ||
            c.voiceOut.length > kMaxButtonTextLength ||
            !seenIds.add(c.id)) {
          continue;
        }
        // A photo never travels; a path in the file means nothing here.
        customs.add(c.withImagePath(''));
      }
    }

    final shared = <AACBoard>[];
    final seenBoards = <String>{};
    final rawShared = json['shared_boards'];
    if (rawShared is List) {
      for (final e in rawShared.take(maxSharedBoards)) {
        if (e is! Map) continue;
        try {
          final b = AACBoard.fromJson(Map<String, dynamic>.from(e));
          BoardPackImporter.validateImportedIds(b, 'setup');
          if (b.buttons.any(
            (x) =>
                x.id.length > _maxSharedButtonIdLength ||
                (x.linkId?.length ?? 0) > _maxSharedButtonIdLength,
          )) {
            continue;
          }
          if (!seenBoards.add(b.boardId)) continue;
          shared.add(
            b.copyWithButtons([
              for (final x in b.buttons)
                x.withIconUri(BoardPackImporter.safeImportedIconUri(x.iconUri)),
            ]),
          );
        } catch (_) {
          continue;
        }
      }
    }

    final pins = <ButtonRef>[];
    final rawPins = json['pins'];
    if (rawPins is List) {
      for (final e in rawPins.take(maxPins)) {
        if (e is Map &&
            e['board_id'] is String &&
            e['button_id'] is String &&
            _isSafeId(e['button_id'] as String)) {
          pins.add((
            boardId: e['board_id'] as String,
            buttonId: e['button_id'] as String,
          ));
        }
      }
    }

    BoardLayout layout = const BoardLayout.empty();
    final rawLayout = json['layout'];
    if (rawLayout is Map) {
      try {
        layout = BoardLayout.fromJson(Map<String, dynamic>.from(rawLayout));
      } catch (_) {
        /* left out */
      }
    }
    HiddenTiles hidden = const HiddenTiles.empty();
    final rawHidden = json['hidden'];
    if (rawHidden is Map) {
      try {
        hidden = HiddenTiles.fromJson(Map<String, dynamic>.from(rawHidden));
      } catch (_) {
        /* left out */
      }
    }

    return DeviceSetup(
      settings: SetupSettings.fromJson(json['settings']),
      customButtons: customs,
      layout: layout,
      hidden: hidden,
      pins: pins,
      sharedBoards: shared,
    );
  }

  /// The same rule the importer applies to a shared board's button ids: no
  /// path separators, `..`, NUL, or the learning-key delimiters `|` and `:`.
  static bool _isSafeId(String id) =>
      id.isNotEmpty &&
      id.length <= kMaxButtonTextLength &&
      !RegExp(r'[/\\|:\x00]').hasMatch(id) &&
      !id.contains('..');
}

/// A setup with every id made fresh for the receiving device, ready to store.
class PreparedSetup {
  const PreparedSetup({
    required this.settings,
    required this.customButtons,
    required this.counters,
    required this.layout,
    required this.hidden,
    required this.pins,
    required this.sharedBoards,
  });

  final SetupSettings settings;
  final List<CustomButton> customButtons;

  /// The receiving device's id high-water marks after the new ids, to merge
  /// into the custom button store.
  final Map<String, int> counters;
  final BoardLayout layout;
  final HiddenTiles hidden;
  final List<ButtonRef> pins;
  final List<AACBoard> sharedBoards;
}

/// Gives every parent-made word, category page and shared board in [setup] a
/// fresh id on the receiving device, and points everything that refers to them
/// (pins, arrangement, hidden words, the words a button replaced) at the new
/// ids. Built-in boards and words keep their ids: they are the same words on
/// every device.
///
/// [counters] are the receiving device's custom id high-water marks;
/// [bundledBoardIds] are the boards that ship with the app; [newSharedBoardId]
/// hands out a never-used shared board id. Anything that refers to a board
/// the setup does not bring (or that does not exist here) is left out, so it
/// can never attach itself to an unrelated board later.
Future<PreparedSetup> prepareForDevice(
  DeviceSetup setup, {
  required Map<String, int> counters,
  required Set<String> bundledBoardIds,
  required Future<String> Function() newSharedBoardId,
}) async {
  // Shared boards: never one posing as a built-in board or a category page.
  final boardMap = <String, String>{};
  final sharedOld = <String>{};
  final keptShared = <AACBoard>[];
  for (final b in setup.sharedBoards) {
    if (bundledBoardIds.contains(b.boardId) ||
        isParentCategoryPage(b.boardId) ||
        boardMap.containsKey(b.boardId)) {
      continue;
    }
    boardMap[b.boardId] = await newSharedBoardId();
    sharedOld.add(b.boardId);
    keptShared.add(b);
  }

  // Parent-made words that can be reached: those on a built-in or shared
  // board, and (following category folders) on the pages they open. A folder
  // that opens nothing the setup brings is left out with its page.
  final byBoard = <String, List<CustomButton>>{};
  for (final c in setup.customButtons) {
    (byBoard[c.boardId] ??= []).add(c);
  }
  final keptIds = <String>{};
  final seenPages = <String>{};
  final pending = <String>[
    for (final id in byBoard.keys)
      if (bundledBoardIds.contains(id) || sharedOld.contains(id)) id,
  ];
  while (pending.isNotEmpty) {
    for (final c in byBoard[pending.removeLast()] ?? const <CustomButton>[]) {
      final link = c.linkId;
      if (link == null) {
        keptIds.add(c.id);
      } else if (isParentCategoryPage(link)) {
        keptIds.add(c.id);
        if (seenPages.add(link)) pending.add(link);
      } else if (sharedOld.contains(link)) {
        keptIds.add(c.id);
      }
    }
  }
  final kept = [
    for (final c in setup.customButtons)
      if (keptIds.contains(c.id)) c,
  ];

  // Category pages, numbered in the order they appear.
  var nextPage = counters[CustomButtonStore.categoryCounterKey] ?? 0;
  for (final c in kept) {
    for (final id in [c.linkId, c.boardId]) {
      if (id != null && isParentCategoryPage(id) && !boardMap.containsKey(id)) {
        boardMap[id] = 'cat_${nextPage++}';
      }
    }
  }
  String? mapBoard(String id) =>
      bundledBoardIds.contains(id) ? id : boardMap[id];

  // Parent-made words: `custom_<board>_<n>` from this device's marks.
  final idMap = <String, String>{};
  final marks = <String, int>{};
  for (final c in kept) {
    final board = mapBoard(c.boardId)!;
    final n = marks[board] ?? counters[board] ?? 0;
    idMap[c.id] = 'custom_${board}_$n';
    marks[board] = n + 1;
  }
  if (nextPage != (counters[CustomButtonStore.categoryCounterKey] ?? 0)) {
    marks[CustomButtonStore.categoryCounterKey] = nextPage;
  }

  String sharedButtonId(String oldBoard, String newBoard, String id) {
    final prefix = '${oldBoard}__';
    final rest = id.startsWith(prefix) ? id.substring(prefix.length) : id;
    return '${newBoard}__$rest';
  }

  ButtonRef? mapRef(String board, String button) {
    final newBoard = mapBoard(board);
    if (newBoard == null) return null;
    final mine = idMap[button];
    if (mine != null) return (boardId: newBoard, buttonId: mine);
    // A parent-made word that did not come over: its id could be handed out
    // here later, and must not find this entry waiting for it.
    if (button.startsWith('custom_')) return null;
    if (sharedOld.contains(board)) {
      return (
        boardId: newBoard,
        buttonId: sharedButtonId(board, newBoard, button),
      );
    }
    return (boardId: newBoard, buttonId: button);
  }

  final customs = [
    for (final c in kept)
      CustomButton(
        id: idMap[c.id]!,
        boardId: mapBoard(c.boardId)!,
        row: c.row,
        col: c.col,
        label: c.label,
        voiceOut: c.voiceOut,
        imagePath: '',
        tileColor: c.tileColor,
        replacesId: c.replacesId == null
            ? null
            : mapRef(c.boardId, c.replacesId!)?.buttonId,
        linkId: c.linkId == null ? null : mapBoard(c.linkId!),
      ),
  ];

  final shared = [
    for (final b in keptShared)
      AACBoard(
        schemaVersion: b.schemaVersion,
        boardId: boardMap[b.boardId]!,
        boardName: b.boardName,
        boardNameByLocale: b.boardNameByLocale,
        gridDimensions: b.gridDimensions,
        colorKey: b.colorKey,
        tileColor: b.tileColor,
        buttons: [
          for (final x in b.buttons)
            AACButton(
              id: sharedButtonId(b.boardId, boardMap[b.boardId]!, x.id),
              label: x.label,
              labelByLocale: x.labelByLocale,
              type: x.type,
              position: x.position,
              category: x.category,
              baseWeight: x.baseWeight,
              iconUri: BoardPackImporter.safeImportedIconUri(x.iconUri),
              voiceOut: x.voiceOut,
              voiceOutByLocale: x.voiceOutByLocale,
              // A shared board carries no folders (the exporter drops them);
              // any link is kept inside the board's own id space, as on import.
              linkId: x.linkId == null
                  ? null
                  : sharedButtonId(b.boardId, boardMap[b.boardId]!, x.linkId!),
              tileColor: x.tileColor,
            ),
        ],
      ),
  ];

  Map<String, dynamic> remapPerBoard(
    Map<String, dynamic> json,
    Object? Function(String board, Object? value) remapValue,
  ) {
    final out = <String, dynamic>{};
    for (final e in json.entries) {
      final newBoard = mapBoard(e.key);
      if (newBoard == null) continue;
      final value = remapValue(e.key, e.value);
      if (value != null) out[newBoard] = value;
    }
    return out;
  }

  final layout = BoardLayout.fromJson(
    remapPerBoard(setup.layout.toJson(), (board, value) {
      if (value is! Map) return null;
      return {
        for (final e in value.entries)
          if (mapRef(board, e.key.toString()) case final r?)
            r.buttonId: e.value,
      };
    }),
  );
  final hidden = HiddenTiles.fromJson(
    remapPerBoard(setup.hidden.toJson(), (board, value) {
      if (value is! List) return null;
      return [
        for (final id in value)
          if (id is String)
            if (mapRef(board, id) case final r?) r.buttonId,
      ];
    }),
  );
  final pins = [
    for (final p in setup.pins)
      if (mapRef(p.boardId, p.buttonId) case final r?) r,
  ];

  return PreparedSetup(
    settings: setup.settings,
    customButtons: customs,
    counters: marks,
    layout: layout,
    hidden: hidden,
    pins: pins,
    sharedBoards: shared,
  );
}
