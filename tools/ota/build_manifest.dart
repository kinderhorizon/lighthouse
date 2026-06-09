/// OTA content-manifest builder (ADR 0017).
///
/// Walks a content-overlay directory (ONLY the corrected files that differ from
/// the bundled app, not the whole catalog) and emits a manifest.json: for each
/// file, its content-root-relative path, sha256, and byte size. Reuses the
/// app's own [ContentManifest] model so the emitted schema can never drift from
/// what the device parses.
///
///   dart run tools/ota/build_manifest.dart \
///     --content ./ota-content \
///     --content-version 2026.05.31 \
///     --sequence 3 \
///     [--min-app-version 1.2.0] \
///     [--target-version 0.1.0+8] \
///     [--prev ./published/manifest.json] \
///     [--out ./ota-content/manifest.json]
///
/// `--target-version` (ADR 0021) tags the manifest with the combined
/// `"<version>+<build>"` release that has ALREADY shipped these corrections in
/// its bundle; the client then stops re-offering them to that release and newer.
/// Omit it until the fold has actually shipped (a forward promise that slips
/// would silently drop the correction for users on that build). When omitted the
/// field is absent from the manifest.
///
/// `sequence` MUST strictly increase with every publish: the device refuses any
/// manifest whose sequence is <= the applied one (downgrade-attack guard). Pass
/// --prev to assert the new sequence is greater than the last published one
/// before writing, so a stale number is caught at authoring time, not in the field.
///
/// After building, sign the EXACT emitted bytes with tools/ota/sign_manifest.dart.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
// Import the pure-Dart manifest model directly, NOT the ota.dart barrel: the
// barrel pulls in content_overlay_store -> path_provider -> dart:ui, which a
// plain `dart run` (no Flutter engine) cannot load. The model layer
// (aac_board -> aac_button) is likewise pure Dart, so AACBoard.fromJson is
// usable here to validate the board files we sign (ADR 0017 / 0014).
import 'package:lighthouse/models/aac_board.dart';
import 'package:lighthouse/services/ota/content_manifest.dart';

Future<int> main(List<String> args) async {
  final contentDir = _argValue(args, '--content');
  final contentVersion = _argValue(args, '--content-version');
  final sequenceRaw = _argValue(args, '--sequence');
  final minAppVersion = _argValue(args, '--min-app-version');
  final targetVersion = _argValue(args, '--target-version');
  final prevPath = _argValue(args, '--prev');

  if (contentDir == null || contentVersion == null || sequenceRaw == null) {
    stderr.writeln('usage: dart run tools/ota/build_manifest.dart '
        '--content <dir> --content-version <str> --sequence <int> '
        '[--min-app-version <str>] [--target-version <version+build>] '
        '[--prev <manifest.json>] [--out <path>]');
    return 64;
  }
  final sequence = int.tryParse(sequenceRaw);
  if (sequence == null || sequence < 0) {
    stderr.writeln('--sequence must be a non-negative integer');
    return 64;
  }

  final root = Directory(contentDir);
  if (!root.existsSync()) {
    stderr.writeln('content directory not found: $contentDir');
    return 66;
  }
  final outPath = _argValue(args, '--out') ??
      '${root.path}${Platform.pathSeparator}manifest.json';

  // Authoring-time monotonic check (the device enforces it too).
  if (prevPath != null) {
    final prev = ContentManifest.parse(File(prevPath).readAsStringSync());
    if (sequence <= prev.sequence) {
      stderr.writeln('refusing: --sequence $sequence is not greater than the '
          'previous published sequence ${prev.sequence}. Bump it.');
      return 65;
    }
  }

  // For a board overlay that REPLACES a bundled board, the button-id-
  // preservation invariant (ADR 0014) is checked against the shipped board of
  // the same id. Default to the repo's boards/ dir (this script lives at
  // tools/ota/); overridable for tests / non-standard layouts.
  final bundledBoardsArg = _argValue(args, '--bundled-boards');
  final bundledBoardsDir = bundledBoardsArg != null
      ? Directory(bundledBoardsArg)
      : Directory.fromUri(Platform.script.resolve('../../boards'));
  final canCheckIds = bundledBoardsDir.existsSync();
  if (!canCheckIds) {
    stderr.writeln('WARNING: bundled boards dir not found '
        '(${bundledBoardsDir.path}); the button-id-preservation check for '
        'board overlays is SKIPPED. Pass --bundled-boards <dir> to enable it.');
  }

  final entries = <ContentManifestEntry>[];
  final rootPath = root.absolute.path;
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    var rel = entity.absolute.path.substring(rootPath.length);
    rel = rel.replaceAll(Platform.pathSeparator, '/');
    if (rel.startsWith('/')) rel = rel.substring(1);
    // The manifest and its signature describe the OTHER files, not themselves.
    if (rel == 'manifest.json' || rel == 'manifest.json.sig') continue;
    if (!ContentManifestEntry.isSafeRelativePath(rel)) {
      stderr.writeln('unsafe content path: $rel');
      return 65;
    }
    final bytes = entity.readAsBytesSync();
    entries.add(ContentManifestEntry(
      path: rel,
      sha256: sha256.convert(bytes).toString(),
      bytes: bytes.length,
    ));

    // ADR 0017: validate every board JSON we sign. The signature chain proves
    // PROVENANCE, not that the file parses on-device; a signed-but-unparseable
    // board would render an error screen on the grid on every launch. Parse it
    // here, at authoring time (this tool previously signed board bytes without
    // ever decoding them). Review items 11 + 12.
    if (rel.startsWith('boards/') && rel.endsWith('.json')) {
      final AACBoard overlayBoard;
      try {
        overlayBoard = AACBoard.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
      } catch (e) {
        stderr.writeln('board "$rel" does not parse as an AACBoard: $e');
        return 65;
      }
      // Enforce button-id preservation for a board that replaces a bundled one
      // (item 12). Bandit arms, glow, favourites, layout, recordings, icon
      // overrides and hidden tiles all key on button.id, so a corrected board
      // that drops or renames an id silently detaches months of learned state
      // and parent customization. Require the overlay to cover every bundled id
      // (additions are fine; removals / renames are not).
      if (canCheckIds) {
        final bundledFile = File(
            '${bundledBoardsDir.path}/${rel.substring('boards/'.length)}');
        if (bundledFile.existsSync()) {
          final AACBoard bundledBoard;
          try {
            bundledBoard = AACBoard.fromJson(
                jsonDecode(bundledFile.readAsStringSync())
                    as Map<String, dynamic>);
          } catch (e) {
            stderr.writeln(
                'bundled board ${bundledFile.path} does not parse: $e');
            return 70;
          }
          final overlayIds = {for (final b in overlayBoard.buttons) b.id};
          final missing = [
            for (final b in bundledBoard.buttons)
              if (!overlayIds.contains(b.id)) b.id,
          ];
          if (missing.isNotEmpty) {
            stderr.writeln(
                'board overlay "$rel" drops or renames button id(s) present in '
                'the bundled board: ${missing.join(', ')}. Learned state and '
                'customization key on button.id (ADR 0014); preserve every id, '
                'or ship this as a new board id.');
            return 65;
          }
        }
      }
    }
  }
  entries.sort((a, b) => a.path.compareTo(b.path));

  final manifest = ContentManifest(
    schemaVersion: 1,
    sequence: sequence,
    contentVersion: contentVersion,
    minAppVersion: minAppVersion,
    targetVersion: targetVersion,
    files: entries,
  );

  const encoder = JsonEncoder.withIndent('  ');
  File(outPath).writeAsStringSync('${encoder.convert(manifest.toJson())}\n',
      flush: true);

  stdout.writeln('Wrote $outPath');
  stdout.writeln('  sequence:        $sequence');
  stdout.writeln('  contentVersion:  $contentVersion');
  if (minAppVersion != null) {
    stdout.writeln('  minAppVersion:   $minAppVersion');
  }
  if (targetVersion != null) {
    stdout.writeln('  targetVersion:   $targetVersion');
  }
  stdout.writeln('  files:           ${entries.length}');
  stdout.writeln('Next: sign it with tools/ota/sign_manifest.dart');
  return 0;
}

String? _argValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}
