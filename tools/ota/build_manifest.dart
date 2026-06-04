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
// plain `dart run` (no Flutter engine) cannot load.
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
