/// Persistence for parent-authored board layout overrides (ADR 0014).
///
/// Stores the [BoardLayout] as a single JSON file in the app support directory,
/// the SAME backup-excluded location as custom buttons and favourites (ADR 0012
/// / 0013 / 0002), so all parent-authored board customization shares one backup
/// posture. A corrupt or partial file loads as an empty layout: a bad overlay
/// must never block the board.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/models.dart';
import '../util/atomic_file.dart';

class BoardLayoutStore {
  BoardLayoutStore({Directory? dirOverride}) : _dirOverride = dirOverride;

  final Directory? _dirOverride;

  static const String fileName = 'board_layout.json';

  Directory? _resolvedBase;

  Future<File> _file() async {
    if (_resolvedBase == null) {
      final base = _dirOverride ?? await getApplicationSupportDirectory();
      if (!base.existsSync()) await base.create(recursive: true);
      _resolvedBase = base;
    }
    return File('${_resolvedBase!.path}/$fileName');
  }

  /// Loads the layout. Empty on first run or any corruption.
  Future<BoardLayout> load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return const BoardLayout.empty();
      final raw = jsonDecode(await f.readAsString());
      if (raw is! Map) return const BoardLayout.empty();
      return BoardLayout.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const BoardLayout.empty();
    }
  }

  Future<void> save(BoardLayout layout) async {
    final f = await _file();
    // Atomic write so an interrupted save cannot truncate the layout overrides.
    await writeStringAtomically(f, jsonEncode(layout.toJson()));
  }
}
