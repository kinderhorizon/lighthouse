/// Copying a child's whole setup to another device (ADR 0023): writing it to a
/// file on this device, and putting a file's setup in place of this device's.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';
import '../board_loader.dart';
import '../board_pack_exporter.dart';
import '../board_registry.dart';
import '../custom/custom_button_store.dart';
import '../favourites/favourites_store.dart';
import '../layout/board_layout_store.dart';
import '../layout/hidden_tiles_store.dart';
import '../layout/icon_override_store.dart';
import '../settings/settings_repository.dart';
import '../util/atomic_file.dart';
import '../voice/custom_voice_store.dart';
import 'device_setup.dart';

/// A setup written to a temp file, ready for the share sheet. The caller MUST
/// delete [file] after the share (like a shared board, ADR 0015), so a child's
/// setup never lingers in a readable cache.
class SetupExport {
  const SetupExport({
    required this.file,
    required this.photosLeftBehind,
    required this.recordingsLeftBehind,
  });

  final File file;

  /// Photos on parent-made buttons plus pictures picked for tiles: they stay
  /// on this device.
  final int photosLeftBehind;

  /// Recorded voices: they stay on this device.
  final int recordingsLeftBehind;
}

class DeviceSetupService {
  DeviceSetupService({
    required this.customButtons,
    required this.layout,
    required this.hidden,
    required this.favourites,
    required this.icons,
    required this.voices,
    required this.settings,
    Directory? tempDirOverride,
  }) : _tempOverride = tempDirOverride;

  final CustomButtonStore customButtons;
  final BoardLayoutStore layout;
  final HiddenTilesStore hidden;
  final FavouritesStore favourites;
  final IconOverrideStore icons;
  final CustomVoiceStore voices;
  final SettingsRepository settings;
  final Directory? _tempOverride;

  /// Everything set up on this device, as a [DeviceSetup]. Shared boards are
  /// read as stored, and a shared board that cannot be read is left out.
  Future<DeviceSetup> collect(BoardRegistry registry) async {
    final shared = <AACBoard>[];
    for (final id in registry.importedBoardIds()) {
      final file = registry.importedBoardFile(id);
      if (file == null) continue;
      try {
        shared.add(await const BoardLoader().loadFromFile(file));
      } catch (_) {
        // An unreadable shared board stays behind; the rest still travel.
      }
    }
    return DeviceSetup(
      settings: SetupSettings.of(await settings.read()),
      customButtons: [
        for (final c in await customButtons.load()) c.withImagePath(''),
      ],
      layout: await layout.load(),
      hidden: await hidden.load(),
      pins: await favourites.pins(),
      sharedBoards: shared,
    );
  }

  /// Writes this device's setup to a temp `.json` named [fileBaseName] (made
  /// safe by [BoardPackExporter.shareFileName]) and says what stays behind.
  /// Throws [DeviceSetupException] if the setup is too large for the other
  /// device to open.
  Future<SetupExport> prepare(
    BoardRegistry registry, {
    String? fileBaseName,
  }) async {
    final setup = await collect(registry);
    final text = jsonEncode(setup.toJson());
    if (utf8.encode(text).length > BoardLoader.maxFileBytes) {
      throw const DeviceSetupException('setup too large');
    }
    final photos =
        (await customButtons.load())
            .where((c) => c.imagePath.isNotEmpty)
            .length +
        (await icons.load()).length;
    final recordings = (await voices.load()).length;
    final dir = _tempOverride ?? await getTemporaryDirectory();
    final name =
        BoardPackExporter.shareFileName(fileBaseName ?? '') ??
        'lighthouse_setup';
    final file = File('${dir.path}/$name.json');
    await file.writeAsString(text, flush: true);
    return SetupExport(
      file: file,
      photosLeftBehind: photos,
      recordingsLeftBehind: recordings,
    );
  }

  /// Puts [setup] in place of everything set up on this device (ADR 0023).
  ///
  /// Order matters. Everything that can fail on a bad file is worked out in
  /// memory first, before anything is written. The new setup is then written,
  /// and only after that is what the old one leaves behind cleaned up (photos,
  /// recordings and pictures of words that are gone, and the old shared
  /// boards). Recordings and pictures on BUILT-IN words stay: they belong to
  /// the same words on every device, and the file cannot bring them.
  Future<void> apply(DeviceSetup setup, BoardRegistry registry) async {
    // Throws if the store cannot be read: never allocate ids from nothing.
    final counters = await customButtons.counters();
    final oldCustoms = await customButtons.load();
    final oldShared = registry.importedBoardIds();
    final prepared = await prepareForDevice(
      setup,
      counters: counters,
      bundledBoardIds: registry.bundledBoardIds(),
      newSharedBoardId: registry.allocateImportedBoardId,
    );
    final boards = <AACBoard>[];
    for (final b in prepared.sharedBoards) {
      try {
        boards.add(AACBoard.fromJson(b.toJson()));
      } catch (e) {
        throw DeviceSetupException('a shared board could not be checked: $e');
      }
    }

    // The new setup. New shared boards first: until the buttons that open
    // them are written they are only extra boards in Settings, Shared boards.
    for (final b in boards) {
      final dest = await registry.importDestinationFor(b.boardId);
      if (!dest.parent.existsSync()) await dest.parent.create(recursive: true);
      await writeStringAtomically(dest, jsonEncode(b.toJson()));
      registry.registerFile(b.boardId, dest.path);
    }
    await customButtons.replaceAll(prepared.customButtons, prepared.counters);
    await layout.save(prepared.layout);
    await hidden.save(prepared.hidden);
    await favourites.replaceAll(prepared.pins);
    await _applySettings(prepared.settings);

    // What the old setup leaves behind. Each step on its own: a failure here
    // leaves an unused file, never a wrong word.
    final oldPages = {
      for (final c in oldCustoms)
        if (c.linkId != null && isParentCategoryPage(c.linkId!)) c.linkId!,
      for (final c in oldCustoms)
        if (isParentCategoryPage(c.boardId)) c.boardId,
    };
    await _quietly(() async {
      final clips = await voices.load();
      await voices.removeMany([
        for (final c in oldCustoms) c.id,
        for (final id in clips.keys)
          if (oldShared.any((s) => id.startsWith('${s}__'))) id,
      ]);
    });
    await _quietly(() async {
      final pictures = await icons.load();
      for (final c in oldCustoms) {
        if (pictures.containsKey(IconOverrideStore.key(c.boardId, c.id))) {
          await icons.clear(c.boardId, c.id);
        }
      }
      for (final page in {...oldPages, ...oldShared}) {
        await icons.resetBoard(page);
      }
    });
    for (final id in oldShared) {
      await _quietly(() => registry.removeImported(id));
    }
  }

  Future<void> _applySettings(SetupSettings s) async {
    if (s.ttsMode != null) await settings.setTtsMode(s.ttsMode!);
    if (s.glowStyle != null) await settings.setGlowStyle(s.glowStyle!);
    if (s.hitboxMagnitude != null) {
      await settings.setHitboxMagnitude(s.hitboxMagnitude!);
    }
    if (s.hasLocale) await settings.setLocaleOverride(s.localeOverride);
    if (s.autoReturnToHome != null) {
      await settings.setAutoReturnToHome(s.autoReturnToHome!);
    }
    // Text and pictures are never both hidden: show first, then hide.
    if (s.hideTileText == false) await settings.setHideTileText(false);
    if (s.hidePictogram == false) await settings.setHidePictogram(false);
    if (s.hideTileText == true) {
      await settings.setHidePictogram(false);
      await settings.setHideTileText(true);
    }
    if (s.hidePictogram == true) {
      await settings.setHideTileText(false);
      await settings.setHidePictogram(true);
    }
  }

  static Future<void> _quietly(Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      stderr.writeln('DeviceSetupService: cleanup step failed: $e');
    }
  }
}
