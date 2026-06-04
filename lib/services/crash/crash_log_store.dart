/// Local crash log storage.
///
/// Stores one JSON file per crash inside the platform application **cache**
/// directory. Cache placement is load-bearing for ADR 0002: on iOS, the
/// cache directory is excluded from iCloud Backup by Apple convention, so
/// crash logs never leave the device via the OS backup channel.
///
/// Rolling buffer: at most 20 entries on disk. Total size cap: 10 MB.
/// When either limit is reached, the oldest entries are removed first
/// (FIFO by filename, which embeds the captured timestamp).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'crash_log.dart';

class CrashLogStore {
  CrashLogStore({Directory? cacheDirOverride})
      : _cacheDirOverride = cacheDirOverride;

  static const int maxEntries = 20;
  static const int maxTotalBytes = 10 * 1024 * 1024; // 10 MB

  /// Subdirectory name inside the cache directory. Kept simple and
  /// platform-independent. The whole directory is gitignored at runtime
  /// since it lives outside the bundle.
  static const String subdirName = 'crash_logs';

  final Directory? _cacheDirOverride;
  Directory? _resolvedDir;

  Future<Directory> _dir() async {
    if (_resolvedDir != null) return _resolvedDir!;
    final base = _cacheDirOverride ?? await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/$subdirName');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    _resolvedDir = dir;
    return dir;
  }

  /// Write a crash log and prune.
  Future<File> write(CrashLog log) async {
    final dir = await _dir();
    final filename = _filenameFor(log.timestamp);
    final file = File('${dir.path}/$filename');
    await file.writeAsString(log.toJsonString(), flush: true);
    await _prune();
    return file;
  }

  /// All logs currently on disk, oldest first.
  Future<List<File>> list() async {
    final dir = await _dir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// Reads + parses every log on disk. Used by the "View crash logs"
  /// preview screen so the user can verify what would be shared.
  Future<List<CrashLog>> readAll() async {
    final files = await list();
    final logs = <CrashLog>[];
    for (final f in files) {
      try {
        final raw = await f.readAsString();
        logs.add(CrashLog.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Malformed entry; skip silently. We don't surface parse errors to
        // the user since the UI is "preview what would be shared" and a
        // malformed entry already won't survive any consumer's parser.
      }
    }
    return logs;
  }

  /// Delete all logs. Used by Settings "Clear crash logs" once UI lands.
  Future<void> clear() async {
    final dir = await _dir();
    for (final f in dir.listSync().whereType<File>()) {
      await f.delete();
    }
  }

  Future<void> _prune() async {
    final files = (await list()); // oldest first
    while (files.length > maxEntries) {
      await files.removeAt(0).delete();
    }
    var total = 0;
    for (final f in files) {
      total += await f.length();
    }
    while (total > maxTotalBytes && files.isNotEmpty) {
      final removed = files.removeAt(0);
      total -= await removed.length();
      await removed.delete();
    }
  }

  String _filenameFor(DateTime ts) {
    final utc = ts.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return 'crash_'
        '${utc.year}${two(utc.month)}${two(utc.day)}_'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}_'
        '${three(utc.millisecond)}.json';
  }
}
