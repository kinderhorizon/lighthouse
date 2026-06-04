/// Persistence for parent-authored tile visibility (ADR 0019).
///
/// Stores [HiddenTiles] as a single JSON file in the app support directory, the
/// SAME backup-excluded location as the board layout, custom buttons, and
/// favourites (ADR 0002 / 0012 / 0013 / 0014), so all parent-authored board
/// customization shares one backup posture. A corrupt or partial file loads as
/// empty: a bad overlay must never block the board (the child would see every
/// hidden tile reappear, which is safe).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';
import '../util/atomic_file.dart';

class HiddenTilesStore {
  HiddenTilesStore({Directory? dirOverride}) : _dirOverride = dirOverride;

  final Directory? _dirOverride;

  static const String fileName = 'hidden_tiles.json';

  Directory? _resolvedBase;

  Future<File> _file() async {
    if (_resolvedBase == null) {
      final base = _dirOverride ?? await getApplicationSupportDirectory();
      if (!base.existsSync()) await base.create(recursive: true);
      _resolvedBase = base;
    }
    return File('${_resolvedBase!.path}/$fileName');
  }

  /// Loads the hidden set. Empty on first run or any corruption.
  Future<HiddenTiles> load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return const HiddenTiles.empty();
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return const HiddenTiles.empty();
      return HiddenTiles.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const HiddenTiles.empty();
    }
  }

  Future<void> save(HiddenTiles hidden) async {
    final f = await _file();
    // Atomic write so an interrupted save cannot truncate the hidden set.
    await writeStringAtomically(f, jsonEncode(hidden.toJson()));
  }
}
