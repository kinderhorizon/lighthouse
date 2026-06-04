/// Tightens TRAILING silence on the already-rendered bundled clips, in place,
/// and updates assets/audio/manifest.json (the content sha256 of each clip).
///
/// Why: the per-word neural clips carry a soft decay tail (sub -40 dB) that the
/// generator's conservative -50 dB end-trim leaves behind. Played one word per
/// tap that tail is inaudible, but the sentence-REPLAY concatenates the clips
/// into one gapless playlist, and those stacked tails make the replay sound
/// unnaturally slow (clinical-lead feedback, 2026-05-30). This trims only the
/// trailing silence (leading is left alone so a soft consonant onset is never
/// clipped), keeping 0.02 s of pad, then rewrites each clip and its manifest
/// sha256 so `tools/verify_assets.dart` still passes.
///
/// One-time data migration, but kept committed + re-runnable: it is idempotent
/// (a tight clip loses nothing) and matches the trailing-trim the generator now
/// applies to fresh renders (see _postProcess in generate_clips.dart). Requires
/// ffmpeg on PATH; clips are committed, so run it from the repo root:
///   dart run tools/tts/tighten_silence.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Trailing-silence trim, mirroring the generator's end-trim parameters.
const List<String> _trailingTrimFilter = [
  'areverse',
  'silenceremove=start_periods=1:start_silence=0.02:start_threshold=-40dB',
  'areverse',
];

double? _durationSeconds(String path) {
  final r = Process.runSync('ffprobe', [
    '-v',
    'error',
    '-show_entries',
    'format=duration',
    '-of',
    'default=nw=1:nk=1',
    path,
  ]);
  return double.tryParse((r.stdout as String).trim());
}

void main() {
  final root = Directory.current.path;
  final manifestPath = '$root/assets/audio/manifest.json';
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('tighten_silence: manifest not found at $manifestPath');
    exit(1);
  }
  if (Process.runSync('ffmpeg', ['-version']).exitCode != 0) {
    stderr.writeln('tighten_silence: ffmpeg not on PATH');
    exit(1);
  }

  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final clips = (manifest['clips'] as List).cast<Map<String, dynamic>>();

  var failed = 0;
  var totalBefore = 0.0;
  var totalAfter = 0.0;
  // Two buttons that share a voice_out string in one locale share a clip file
  // (the filename is text-hashed), so the manifest can list the same path
  // twice. Trim each PATH exactly once, then resync every entry's sha from the
  // final bytes, so duplicate entries do not get a stale (double-trimmed) hash.
  final done = <String>{};

  for (final clip in clips) {
    final rel = clip['path'] as String;
    if (!done.add(rel)) continue;
    final path = '$root/$rel';
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('  ! missing clip, skipping: $rel');
      failed++;
      continue;
    }
    final before = _durationSeconds(path) ?? 0;
    final tmp = '$path.trim.mp3';
    final result = Process.runSync('ffmpeg', [
      '-y',
      '-i',
      path,
      '-af',
      _trailingTrimFilter.join(','),
      '-ar',
      '24000',
      tmp,
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('  ! ffmpeg failed for $rel: ${result.stderr}');
      if (File(tmp).existsSync()) File(tmp).deleteSync();
      failed++;
      continue;
    }
    final after = _durationSeconds(tmp) ?? before;
    totalBefore += before;
    // Idempotency guard: the trim is duration-idempotent but NOT encode-
    // idempotent (a second run would still decode->re-encode the mp3, losing
    // quality and churning every sha). If this clip is already tight (the trim
    // removed essentially nothing), keep the original bytes untouched.
    const epsilonSeconds = 0.015;
    if (before - after < epsilonSeconds) {
      File(tmp).deleteSync();
      totalAfter += before;
    } else {
      file.writeAsBytesSync(File(tmp).readAsBytesSync(), flush: true);
      File(tmp).deleteSync();
      totalAfter += after;
    }
    if (done.length % 50 == 0) stdout.writeln('  ...${done.length} paths');
  }

  // Resync sha256 for every entry (including duplicate-path entries) from the
  // final on-disk bytes.
  for (final clip in clips) {
    final f = File('$root/${clip['path']}');
    if (f.existsSync()) {
      clip['sha256'] = sha256.convert(f.readAsBytesSync()).toString();
    }
  }

  manifestFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest),
    flush: true,
  );
  final processed = done.length;

  final saved = totalBefore - totalAfter;
  stdout.writeln('tighten_silence: processed=$processed failed=$failed '
      'totalBefore=${totalBefore.toStringAsFixed(1)}s '
      'totalAfter=${totalAfter.toStringAsFixed(1)}s '
      'trimmed=${saved.toStringAsFixed(1)}s '
      '(${totalBefore == 0 ? 0 : (saved / totalBefore * 100).toStringAsFixed(1)}%)');
}
