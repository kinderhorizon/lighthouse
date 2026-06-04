/// Persistence for home-favourite pins (ADR 0013).
///
/// Stores the parent's pinned button references as a JSON file in the app
/// support directory, the SAME backup-excluded location as custom buttons
/// (ADR 0012 / ADR 0002), so all parent-authored board customization shares one
/// backup posture rather than three. A pin is just a {boardId, buttonId} ref.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../logic/favourites/favourite_ranking.dart';
import '../util/atomic_file.dart';

class FavouritesStore {
  FavouritesStore({Directory? dirOverride}) : _dirOverride = dirOverride;

  final Directory? _dirOverride;

  static const String fileName = 'home_favourites.json';

  Directory? _resolvedBase;

  Future<File> _file() async {
    if (_resolvedBase == null) {
      final base = _dirOverride ?? await getApplicationSupportDirectory();
      if (!base.existsSync()) await base.create(recursive: true);
      _resolvedBase = base;
    }
    return File('${_resolvedBase!.path}/$fileName');
  }

  /// Loads the pinned refs in order. Empty on first run or on corruption (a
  /// bad file must never block the home screen).
  Future<List<ButtonRef>> pins() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return const [];
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map &&
              e['board_id'] is String &&
              e['button_id'] is String)
            (boardId: e['board_id'] as String, buttonId: e['button_id'] as String),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveAll(List<ButtonRef> refs) async {
    final f = await _file();
    // Atomic write so an interrupted save cannot truncate the pinned list.
    await writeStringAtomically(
        f,
        jsonEncode([
          for (final r in refs)
            {'board_id': r.boardId, 'button_id': r.buttonId},
        ]));
  }

  /// Adds [ref] (de-duped, appended last) and returns the updated list.
  Future<List<ButtonRef>> pin(ButtonRef ref) async {
    final current = await pins();
    if (current.contains(ref)) return current;
    final next = [...current, ref];
    await _saveAll(next);
    return next;
  }

  /// Removes [ref] and returns the updated list.
  Future<List<ButtonRef>> unpin(ButtonRef ref) async {
    final current = await pins();
    final next = current.where((r) => r != ref).toList();
    await _saveAll(next);
    return next;
  }
}
