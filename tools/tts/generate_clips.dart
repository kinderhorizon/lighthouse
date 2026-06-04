/// Build-time TTS clip generator (maintainer-run, NOT part of any build).
///
/// Pre-renders the fixed core vocabulary to neural audio via Google Cloud
/// Text-to-Speech and bundles the clips under assets/audio/. This is the
/// primary speech path (docs/adr/0004-tts-strategy.md amendment): the vocab is
/// a small finite set, so real-time synthesis is unnecessary and bundling
/// removes the silent-tap failure mode (critical for Arabic).
///
/// It is intentionally NOT wired into any build: it calls a paid API and needs
/// a credential. See tools/tts/README.md for the full run procedure.
///
/// Auth: set GCP_TTS_API_KEY to a Google Cloud API key with the
/// Cloud Text-to-Speech API enabled. The key is a maintainer secret and is
/// never committed.
///
/// Three modes:
///
///   # 1. Confirm which native voices/tiers a locale actually offers.
///   dart run tools/tts/generate_clips.dart list-voices --lang ar
///
///   # 2. Audition: render a small review subset for several candidate voices
///   #    per locale into tools/tts/candidates/ + an index.html for the clinical lead.
///   dart run tools/tts/generate_clips.dart candidates
///
///   # 3. Render the full vocabulary with the chosen voice per locale and
///   #    update assets/audio/manifest.json. Clips ARE committed.
///   dart run tools/tts/generate_clips.dart render \
///       --voice en=en-US-... --voice es=es-US-... --voice ar=ar-XA-...
///
/// Output format is MP3. Google Cloud TTS cannot emit AAC/M4A (its encodings
/// are MP3, OGG_OPUS, LINEAR16, MULAW, ALAW, PCM); MP3 is decoded natively by
/// just_audio on both iOS and Android, so it is the safe zero-transcode choice.
/// If ffmpeg is on PATH, clips are loudness-normalized and silence-trimmed so
/// taps feel instant and no clip is jarringly loud; without ffmpeg the raw API
/// output is written and a warning is logged.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Launch locales whose `ttsStrategy` is `bundledClips` in
/// lib/i18n/locale_registry.dart. The registry is the source of truth; this
/// list must match it, and test/i18n/localization_completeness_test.dart
/// asserts every locale here has full board voice_out coverage. Override at
/// the CLI with `--lang <code>` (repeatable).
const List<String> _defaultLocales = ['en', 'es', 'ar'];

/// Representative review subset for `candidates` mode (high-frequency words a
/// listener can judge quickly, including the emotionally load-bearing ones).
const List<String> _candidateButtonIds = [
  'btn_i',
  'btn_mom',
  'btn_help',
  'btn_stop',
  'btn_water',
  'btn_more',
  'btn_yes',
  'btn_no',
];

/// Candidate voices to audition per locale (verified available 2026-05-28 via
/// `list-voices`). All three launch locales have the Chirp3-HD generative tier,
/// and the persona names are shared across locales, so one persona can be the
/// same warm character in en/es/ar. We audition the FEMALE Chirp3-HD personas
/// (clinical-lead steer: warm + female). Regions: en-US and es-US (Latin
/// American Spanish, matching the launch population, not Castilian es-ES);
/// Arabic has only ar-XA (MSA, per ADR 0008). Narrow this list to the picked
/// finalist(s) after the audition, then `render --voice code=name`.
/// Personas to render in `candidates` mode.
///
/// The full female Chirp3-HD roster auditioned 2026-05-28 (names shared across
/// en-US / es-US / ar-XA): Achernar, Aoede, Autonoe, Callirrhoe, Despina,
/// Erinome, Gacrux, Kore, Laomedeia, Leda, Pulcherrima, Sulafat, Vindemiatrix,
/// Zephyr. Picked finalist: Laomedeia, used as the SAME warm persona across all
/// three locales. To re-run a broad audition, list more personas here.
const List<String> _auditionPersonas = ['Laomedeia'];

final Map<String, List<String>> _candidateVoices = {
  'en': [for (final p in _auditionPersonas) 'en-US-Chirp3-HD-$p'],
  'es': [for (final p in _auditionPersonas) 'es-US-Chirp3-HD-$p'],
  'ar': [for (final p in _auditionPersonas) 'ar-XA-Chirp3-HD-$p'],
};

const String _synthUrl =
    'https://texttospeech.googleapis.com/v1/text:synthesize';
const String _voicesUrl = 'https://texttospeech.googleapis.com/v1/voices';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _usageAndExit();
  }
  final mode = args.first;
  final rest = args.skip(1).toList();

  final minBytes = _optAll(rest, '--min-bytes');
  if (minBytes.isNotEmpty) {
    _minClipBytes = int.tryParse(minBytes.last) ?? _minClipBytes;
  }

  switch (mode) {
    case 'list-voices':
      await _listVoices(_optAll(rest, '--lang'));
    case 'candidates':
      await _candidates(_localesFrom(rest));
    case 'render':
      await _render(_localesFrom(rest), _voiceFlags(rest),
          rest.contains('--force'));
    default:
      _usageAndExit();
  }
}

Never _usageAndExit() {
  stderr.writeln('Usage:');
  stderr.writeln('  dart run tools/tts/generate_clips.dart list-voices [--lang ar]');
  stderr.writeln('  dart run tools/tts/generate_clips.dart candidates [--lang ar ...]');
  stderr.writeln('  dart run tools/tts/generate_clips.dart render '
      '--voice en=NAME --voice es=NAME --voice ar=NAME');
  exit(64); // EX_USAGE
}

/// Credential for the REST API. Two interchangeable modes:
///   - GCP_TTS_API_KEY set -> append `?key=...` (a maintainer secret).
///   - otherwise -> an OAuth bearer token from `gcloud auth print-access-token`
///     plus the quota project header (no secret to mint or store locally).
class _Auth {
  _Auth({this.apiKey, this.bearer, this.quotaProject});

  final String? apiKey;
  final String? bearer;
  final String? quotaProject;

  Uri uri(String base, [Map<String, String> query = const {}]) {
    final params = {...query, if (apiKey != null) 'key': apiKey!};
    return Uri.parse(base).replace(
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Map<String, String> headers([Map<String, String> extra = const {}]) => {
        ...extra,
        if (bearer != null) 'authorization': 'Bearer $bearer',
        if (bearer != null && quotaProject != null)
          'x-goog-user-project': quotaProject!,
      };
}

_Auth _resolveAuth() {
  final key = Platform.environment['GCP_TTS_API_KEY'];
  if (key != null && key.isNotEmpty) return _Auth(apiKey: key);

  final tok = Process.runSync('gcloud', ['auth', 'print-access-token']);
  if (tok.exitCode != 0) {
    stderr.writeln('No GCP_TTS_API_KEY set and `gcloud auth print-access-token` '
        'failed. Set the key, or authenticate gcloud. See tools/tts/README.md.');
    exit(78); // EX_CONFIG
  }
  final project = Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
      (Process.runSync('gcloud', ['config', 'get-value', 'project']).stdout
              as String)
          .trim();
  return _Auth(
    bearer: (tok.stdout as String).trim(),
    quotaProject: project.isEmpty ? null : project,
  );
}

List<String> _localesFrom(List<String> args) {
  final langs = _optAll(args, '--lang');
  return langs.isEmpty ? _defaultLocales : langs;
}

/// Collects all values of a repeatable `--flag value` option.
List<String> _optAll(List<String> args, String flag) {
  final out = <String>[];
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == flag) out.add(args[i + 1]);
  }
  return out;
}

/// Parses repeatable `--voice code=name` into {code: name}.
Map<String, String> _voiceFlags(List<String> args) {
  final out = <String, String>{};
  for (final pair in _optAll(args, '--voice')) {
    final eq = pair.indexOf('=');
    if (eq <= 0) continue;
    out[pair.substring(0, eq)] = pair.substring(eq + 1);
  }
  return out;
}

/// Derives the BCP-47 languageCode a voice name belongs to, e.g.
/// `en-US-Studio-O` -> `en-US`, `ar-XA-Wavenet-A` -> `ar-XA`.
String _languageCodeOf(String voiceName) =>
    voiceName.split('-').take(2).join('-');

/// Every button across EVERY board under boards/ (core + sub-boards), so one
/// render pass covers the whole app. voice_out strings repeated across boards
/// (e.g. "car") dedupe naturally: clips key on (locale, voice_out) content, so
/// the same word renders to the same file regardless of which board it is on.
List<Map<String, dynamic>> _buttons() {
  final dir = Directory('${Directory.current.path}/boards');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final out = <Map<String, dynamic>>[];
  for (final f in files) {
    final board = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    out.addAll((board['buttons'] as List).cast<Map<String, dynamic>>());
  }
  return out;
}

/// Connector / grammar words the sentence composer inserts that are NOT board
/// buttons, so they have no clip unless rendered here. Keyed by locale ->
/// {synthetic clip id: text}. The English infinitive "to" (composeUtteranceTokens
/// inserts it between two verbs, e.g. "want to go") is the only one today; a
/// bundled clip keeps the replay on the warm voice rather than switching to
/// system TTS for that one word (clinical review).
const Map<String, Map<String, String>> _supplementalUtterances = {
  'en': {'connector_to': 'to'},
};

/// The voice_out string for [button] in [locale], or null for folders / a
/// locale with no voice_out (which is a board gap, surfaced by the caller).
String? _voiceOut(Map<String, dynamic> button, String locale) {
  if (button['type'] == 'folder') return null;
  if (locale == 'en') return button['voice_out'] as String?;
  return button['voice_out_$locale'] as String?;
}

// --------------------------------------------------------------------------
// Mode: list-voices
// --------------------------------------------------------------------------

Future<void> _listVoices(List<String> langs) async {
  final auth = _resolveAuth();
  final targets = langs.isEmpty ? _defaultLocales : langs;
  final client = http.Client();
  try {
    for (final lang in targets) {
      final res = await client.get(
        auth.uri(_voicesUrl, {'languageCode': lang}),
        headers: auth.headers(),
      );
      if (res.statusCode != 200) {
        stderr.writeln('[$lang] HTTP ${res.statusCode}: ${res.body}');
        continue;
      }
      final voices =
          ((jsonDecode(res.body) as Map<String, dynamic>)['voices'] as List?) ??
              const [];
      stdout.writeln('[$lang] ${voices.length} voices:');
      for (final v in voices.cast<Map<String, dynamic>>()) {
        stdout.writeln('  ${v['name']}  (${(v['ssmlGender'] ?? '').toString()})');
      }
    }
  } finally {
    client.close();
  }
}

// --------------------------------------------------------------------------
// Mode: candidates
// --------------------------------------------------------------------------

Future<void> _candidates(List<String> locales) async {
  final auth = _resolveAuth();
  final root = Directory.current.path;
  final outDir = Directory('$root/tools/tts/candidates');
  outDir.createSync(recursive: true);

  final buttonsById = {for (final b in _buttons()) b['id'] as String: b};
  final client = http.Client();
  final rows = <String>[];
  try {
    for (final locale in locales) {
      for (final voice in _candidateVoices[locale] ?? const <String>[]) {
        for (final id in _candidateButtonIds) {
          final button = buttonsById[id];
          if (button == null) continue;
          final text = _voiceOut(button, locale);
          if (text == null) continue;
          final bytes = await _synthesize(client, auth, text, voice);
          if (bytes == null) continue;
          // Path relative to index.html, which lives in tools/tts/candidates/.
          final src = '$locale/$voice/$id.mp3';
          final file = File('$root/tools/tts/candidates/$src')
            ..parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes, flush: true);
          rows.add('<tr><td>$locale</td><td>$voice</td><td>$id</td>'
              '<td>$text</td><td><audio controls src="$src"></audio></td></tr>');
          stdout.writeln('[$locale/$voice] $id (${bytes.length} bytes)');
        }
      }
    }
  } finally {
    client.close();
  }

  File('${outDir.path}/index.html').writeAsStringSync(_indexHtml(rows),
      flush: true);
  stdout.writeln('---');
  stdout.writeln('Wrote ${rows.length} candidate clips. Open '
      'tools/tts/candidates/index.html to audition. (Provisional content; '
      'the clinical lead picks the final voice per locale.)');
}

String _indexHtml(List<String> rows) => '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Lighthouse TTS voice candidates</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 2rem; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #ccc; padding: .4rem .6rem; text-align: start; }
  th { background: #1F3A44; color: #fff; }
</style>
</head>
<body>
<h1>Lighthouse TTS voice candidates</h1>
<p>Audition the candidate voices per locale, then pick one voice per locale.
Provisional content for review only; not committed.</p>
<table>
<thead><tr><th>Locale</th><th>Voice</th><th>Button</th><th>Voice-out</th><th>Audio</th></tr></thead>
<tbody>
${rows.join('\n')}
</tbody>
</table>
</body>
</html>
''';

// --------------------------------------------------------------------------
// Mode: render
// --------------------------------------------------------------------------

Future<void> _render(
  List<String> locales,
  Map<String, String> voices,
  bool force,
) async {
  final auth = _resolveAuth();
  final root = Directory.current.path;

  for (final locale in locales) {
    if (!voices.containsKey(locale)) {
      stderr.writeln('No --voice given for "$locale". Pass '
          '--voice $locale=<voiceName> (see list-voices).');
      exit(64);
    }
  }

  final manifestPath = '$root/assets/audio/manifest.json';
  final manifest =
      jsonDecode(File(manifestPath).readAsStringSync()) as Map<String, dynamic>;

  final buttons = _buttons();
  final client = http.Client();
  final clips = <Map<String, dynamic>>[];
  final usedVoices = <String, String>{};
  var rendered = 0;
  var skippedFolders = 0;
  var gaps = 0;
  try {
    for (final locale in locales) {
      final voice = voices[locale]!;
      usedVoices[locale] = voice;

      // Renders one (id, text) to a content-addressed clip and records it in
      // the manifest. Returns false on a synth failure (counted as a gap).
      Future<bool> renderItem(String id, String text) async {
        // Stable per-clip name so changing one word re-renders only that clip,
        // and a word shared across boards (e.g. "car") renders once.
        final stamp =
            sha256.convert(utf8.encode('$locale|$voice|$text')).toString();
        final rel = 'assets/audio/$locale/$stamp.mp3';
        final file = File('$root/$rel')..parent.createSync(recursive: true);

        final List<int> processed;
        if (file.existsSync() && !force) {
          // Idempotent: identical (locale, voice, text) already rendered.
          processed = file.readAsBytesSync();
        } else {
          final bytes = await _synthesize(client, auth, text, voice);
          if (bytes == null) return false;
          processed = _postProcess(bytes, file.path);
        }
        final sha = sha256.convert(processed).toString();
        final durationMs = _durationMs(file.path);
        clips.add({
          'locale': locale,
          'button_id': id,
          'voice_out': text,
          'path': rel,
          'sha256': sha,
          'voice_id': voice,
          if (durationMs != null) 'duration_ms': durationMs,
        });
        rendered++;
        stdout.writeln('[$locale] $id -> $rel (${processed.length} bytes)');
        return true;
      }

      for (final button in buttons) {
        final id = button['id'] as String;
        final text = _voiceOut(button, locale);
        if (button['type'] == 'folder') {
          skippedFolders++;
          continue;
        }
        if (text == null || text.isEmpty) {
          stderr.writeln('  ! board gap: $id has no voice_out for "$locale"');
          gaps++;
          continue;
        }
        if (!await renderItem(id, text)) gaps++;
      }

      // Grammar/connector words the sentence composer inserts but that are not
      // board buttons (e.g. the English infinitive "to" in "want to go"). They
      // need their own bundled clip so the replay stays on the warm voice
      // instead of switching to system TTS for that one word (clinical review).
      for (final entry in (_supplementalUtterances[locale] ?? const {}).entries) {
        if (!await renderItem(entry.key, entry.value)) gaps++;
      }
    }

    manifest['format'] = 'audio/mpeg';
    manifest['voices'] = usedVoices;
    manifest['clips'] = clips
      ..sort((a, b) => ('${a['locale']}${a['button_id']}')
          .compareTo('${b['locale']}${b['button_id']}'));
    File(manifestPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );
  } finally {
    client.close();
  }

  stdout.writeln('---');
  stdout.writeln('rendered: $rendered  folders-skipped: $skippedFolders  '
      'gaps: $gaps');
  stdout.writeln('Now add each `- assets/audio/<locale>/` dir to pubspec.yaml '
      'and run: dart run tools/verify_assets.dart');
  if (gaps > 0) exit(1);
}

/// Cloud TTS occasionally returns a near-silent clip for a short word,
/// non-deterministically (byte size and duration do NOT reliably catch it:
/// an observed dud and an observed real clip were both 1632 bytes / 0.408 s,
/// but the dud peaked at -46 dB vs the real clip's -15 dB). A silent tap is the
/// exact failure this path exists to remove.
///
/// Guard rule: if a clip is weaker than expected, render it up to
/// [_synthAttempts] times and KEEP THE BEST one (loudest peak). Only if every
/// attempt is essentially silent do we return null (a gap, failed loudly), so a
/// silent clip never ships. Loudness uses ffmpeg `volumedetect`; without ffmpeg
/// it falls back to byte size (a weak proxy) with [_minClipBytes].
int _minClipBytes = 1500; // ffmpeg-absent fallback floor; --min-bytes overrides
const int _synthAttempts = 5;
const double _silenceFloorDb = -40.0; // peak below this == effectively silent

/// Calls Cloud TTS with the empty-render guard; returns the best MP3 bytes, or
/// null if every attempt is silent.
Future<List<int>?> _synthesize(
  http.Client client,
  _Auth auth,
  String text,
  String voiceName,
) async {
  final attempts = <List<int>>[];
  for (var i = 1; i <= _synthAttempts; i++) {
    final bytes = await _synthesizeOnce(client, auth, text, voiceName);
    if (bytes == null) continue;
    attempts.add(bytes);
    // First take is fine -> ship it, do not waste the other four calls.
    if (i == 1 && _looksGood(bytes)) return bytes;
    if (i == 1) {
      stderr.writeln('  ~ "$text" ($voiceName) weaker than expected '
          '(${_scoreLabel(bytes)}); rendering up to $_synthAttempts, best wins');
    }
  }
  if (attempts.isEmpty) return null;

  // Decide: keep the loudest (or, without ffmpeg, the largest).
  attempts.sort((a, b) => _rankScore(b).compareTo(_rankScore(a)));
  final best = attempts.first;
  if (!_looksGood(best)) {
    stderr.writeln('  ! "$text" ($voiceName): best of ${attempts.length} still '
        '${_scoreLabel(best)}; gap, not shipping silence');
    return null;
  }
  stderr.writeln('  + "$text" ($voiceName): picked best of ${attempts.length} '
      '(${_scoreLabel(best)})');
  return best;
}

/// True if the clip clears the silence bar (peak >= floor, or byte fallback).
bool _looksGood(List<int> bytes) {
  final peak = _peakDb(bytes);
  if (peak != null) return peak >= _silenceFloorDb;
  return bytes.length >= _minClipBytes;
}

/// Higher is better. Peak dB when ffmpeg is present, else byte size.
double _rankScore(List<int> bytes) => _peakDb(bytes) ?? bytes.length.toDouble();

String _scoreLabel(List<int> bytes) {
  final peak = _peakDb(bytes);
  return peak != null
      ? 'peak ${peak.toStringAsFixed(1)} dB'
      : '${bytes.length} B';
}

/// Peak amplitude in dBFS via ffmpeg `volumedetect`, or null if ffmpeg is
/// absent / unparseable. A near-silent clip reads roughly -45 dB or lower.
double? _peakDb(List<int> bytes) {
  if (!_ffmpegAvailable) return null;
  final tmp = File('${Directory.systemTemp.path}/khf_tts_probe.mp3')
    ..writeAsBytesSync(bytes, flush: true);
  final r = Process.runSync(
    'ffmpeg',
    ['-hide_banner', '-i', tmp.path, '-af', 'volumedetect', '-f', 'null', '-'],
  );
  try {
    tmp.deleteSync();
  } catch (_) {}
  final m = RegExp(r'max_volume:\s*(-?[\d.]+) dB')
      .firstMatch(r.stderr is String ? r.stderr as String : '');
  return m == null ? null : double.tryParse(m.group(1)!);
}

/// Duration of an on-disk clip in milliseconds via ffprobe, or null.
int? _durationMs(String path) {
  if (!_ffmpegAvailable) return null;
  final r = Process.runSync('ffprobe', [
    '-v',
    'error',
    '-show_entries',
    'format=duration',
    '-of',
    'csv=p=0',
    path,
  ]);
  if (r.exitCode != 0) return null;
  final secs = double.tryParse((r.stdout as String).trim());
  return secs == null ? null : (secs * 1000).round();
}

Future<List<int>?> _synthesizeOnce(
  http.Client client,
  _Auth auth,
  String text,
  String voiceName,
) async {
  final res = await client.post(
    auth.uri(_synthUrl),
    headers: auth.headers({'content-type': 'application/json'}),
    body: jsonEncode({
      'input': {'text': text},
      'voice': {
        'languageCode': _languageCodeOf(voiceName),
        'name': voiceName,
      },
      'audioConfig': {
        'audioEncoding': 'MP3',
        'sampleRateHertz': 24000,
      },
    }),
  );
  if (res.statusCode != 200) {
    stderr.writeln('  ! synth HTTP ${res.statusCode} for "$text" ($voiceName): '
        '${res.body}');
    return null;
  }
  final audio = (jsonDecode(res.body) as Map<String, dynamic>)['audioContent']
      as String?;
  if (audio == null) return null;
  return base64Decode(audio);
}

/// Writes [bytes] to [outPath]. If ffmpeg is available, normalizes loudness and
/// trims leading/trailing silence and returns the processed bytes; otherwise
/// writes the raw bytes and warns once.
List<int> _postProcess(List<int> bytes, String outPath) {
  if (!_ffmpegAvailable) {
    File(outPath).writeAsBytesSync(bytes, flush: true);
    if (!_warnedNoFfmpeg) {
      stderr.writeln('  (ffmpeg not found: writing raw clips without loudness '
          'normalization or silence trim)');
      _warnedNoFfmpeg = true;
    }
    return bytes;
  }
  final tmp = File('$outPath.raw')..writeAsBytesSync(bytes, flush: true);
  final result = Process.runSync('ffmpeg', [
    '-y',
    '-i',
    tmp.path,
    '-af',
    // Leading trim stays gentle (-50 dB, keep 0.05 s) so a soft consonant onset
    // is never clipped. The TRAILING trim is tighter (-40 dB, keep 0.02 s):
    // the neural voice leaves a long decay tail that is inaudible per-tap but
    // stacks up across a concatenated sentence replay and makes it drag
    // (clinical-lead feedback 2026-05-30). tools/tts/tighten_silence.dart
    // applies the same trailing trim to already-shipped clips.
    'silenceremove=start_periods=1:start_silence=0.05:start_threshold=-50dB,'
        'areverse,'
        'silenceremove=start_periods=1:start_silence=0.02:start_threshold=-40dB,'
        'areverse,'
        'loudnorm=I=-16:TP=-1.5:LRA=11',
    '-ar',
    '24000',
    outPath,
  ]);
  tmp.deleteSync();
  if (result.exitCode != 0) {
    stderr.writeln('  ! ffmpeg failed for $outPath: ${result.stderr}');
    File(outPath).writeAsBytesSync(bytes, flush: true);
    return bytes;
  }
  return File(outPath).readAsBytesSync();
}

final bool _ffmpegAvailable = () {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}();

bool _warnedNoFfmpeg = false;
