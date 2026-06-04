/// OTA signing-key generator (ADR 0017).
///
/// Generates an Ed25519 key pair for signing content manifests. Prints ONLY
/// the base64 public key (paste it into `kOtaTrustedPublicKeys` in
/// lib/services/ota/ota_config.dart) and writes the 32-byte private seed,
/// base64, to the file named by --out.
///
/// The private seed is the only secret in the OTA chain. It must live on an
/// offline publishing machine and NEVER be committed, shared, or copied into
/// Azure. This tool refuses to write it inside the repo working tree.
///
///   dart run tools/ota/ota_keygen.dart --out ~/khf-keys/ota-signing.key
///
/// Trust-list rotation: generate the NEXT key ahead of time, add its public key
/// to `kOtaTrustedPublicKeys` (alongside the current one) and ship that build,
/// then start signing with the new seed once enough installs accept it.
library;

import 'dart:convert';
import 'dart:io';

import 'ota_signing.dart';

Future<int> main(List<String> args) async {
  final outPath = _argValue(args, '--out');
  if (outPath == null) {
    stderr.writeln('usage: dart run tools/ota/ota_keygen.dart '
        '--out <path-to-private-seed-file>');
    return 64;
  }

  final outFile = File(outPath);
  // Refuse to drop a secret inside the repo (the publish key is offline-only).
  // Resolve the actual repo root by walking up from the cwd to the dir holding
  // pubspec.yaml / .git, so the guard holds even when run from a subdirectory
  // (a plain `Directory.current` check would shrink to that subdir).
  final repoRoot = _repoRoot();
  if (outFile.absolute.path == repoRoot ||
      outFile.absolute.path.startsWith('$repoRoot${Platform.pathSeparator}')) {
    stderr.writeln('refusing to write a private key inside the repo working '
        'tree ($repoRoot). Pick an offline location, e.g. ~/khf-keys/.');
    return 65;
  }
  if (outFile.existsSync()) {
    stderr.writeln('refusing to overwrite existing file: $outPath');
    return 66;
  }

  final pair = await generateKeyPair();
  outFile.writeAsStringSync('${base64.encode(pair.seed)}\n', flush: true);
  // Best-effort tighten to owner-only; harmless if the platform ignores it.
  try {
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['600', outFile.absolute.path]);
    }
  } catch (_) {
    // Non-fatal: the warning below still stands.
  }

  stdout.writeln('Private seed written to: ${outFile.absolute.path}');
  stdout.writeln('KEEP THIS OFFLINE. Never commit it or upload it to Azure.');
  stdout.writeln('');
  stdout.writeln('Public key (add to kOtaTrustedPublicKeys):');
  stdout.writeln('  "${base64.encode(pair.publicKey)}",');
  return 0;
}

String? _argValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}

/// The repo root: the nearest ancestor of the cwd (inclusive) that holds a
/// `pubspec.yaml` or a `.git` entry. Falls back to the cwd if none is found.
String _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    final hasPubspec = File('${dir.path}/pubspec.yaml').existsSync();
    final hasGit = Directory('${dir.path}/.git').existsSync() ||
        File('${dir.path}/.git').existsSync();
    if (hasPubspec || hasGit) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current.absolute.path;
    dir = parent;
  }
}
