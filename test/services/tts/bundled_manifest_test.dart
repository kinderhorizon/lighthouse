/// End-to-end guard: the committed assets/audio/manifest.json must actually
/// cover every speaking button in every locale the registry marks bundledClips.
///
/// This reads the REAL manifest + board from disk and asserts a clip entry
/// exists (and its file is on disk) for each board voice_out, keyed by the same
/// (locale, voice_out) pair the BundledAudioTTSEngine uses at runtime. It
/// catches a partial render (some words silent), a manifest/board key drift, or
/// a locale flipped to bundledClips before its clips were generated. A silent
/// tap is the worst AAC failure, so this is a launch-blocking invariant.
///
/// Pure File/JSON (no rootBundle, no engine, no just_audio) so it stays fast
/// and does not depend on the flutter_test asset bundle.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/i18n/locale_registry.dart';

void main() {
  final manifest =
      jsonDecode(File('assets/audio/manifest.json').readAsStringSync())
          as Map<String, dynamic>;
  final clips = (manifest['clips'] as List).cast<Map<String, dynamic>>();

  // (locale, voice_out) pairs the manifest provides, mirroring the engine key.
  final covered = <String>{
    for (final c in clips) '${c['locale']}\u0000${c['voice_out']}',
  };

  // Every board under boards/ (core + sub-boards): every speaking word in a
  // bundledClips locale must resolve to a committed clip, app-wide.
  final buttons = <Map<String, dynamic>>[];
  for (final f in Directory('boards')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))) {
    final b = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    buttons.addAll((b['buttons'] as List).cast<Map<String, dynamic>>());
  }

  bool isSpeaking(Map<String, dynamic> b) =>
      b['type'] != 'folder' && b['voice_out'] != null;

  String? voiceOut(Map<String, dynamic> b, String code) =>
      code == 'en' ? b['voice_out'] as String? : b['voice_out_$code'] as String?;

  final bundled = LocaleRegistry.all
      .where((s) => s.ttsStrategy == TtsStrategy.bundledClips)
      .toList();

  test('at least one locale is bundled (guards a false pass)', () {
    expect(bundled, isNotEmpty);
  });

  for (final spec in bundled) {
    test('every ${spec.code} core word has a bundled clip', () {
      final missing = <String>[];
      for (final b in buttons) {
        if (!isSpeaking(b)) continue;
        final text = voiceOut(b, spec.code);
        if (text == null || text.isEmpty) continue; // board gap, covered elsewhere
        if (!covered.contains('${spec.code}\u0000$text')) {
          missing.add('${b['id']} ("$text")');
        }
      }
      expect(missing, isEmpty,
          reason: 'no bundled clip for ${spec.code}: $missing');
    });
  }

  test('every manifest clip file exists on disk', () {
    final gone = <String>[];
    for (final c in clips) {
      final path = c['path'] as String;
      if (!File(path).existsSync()) gone.add(path);
    }
    expect(gone, isEmpty, reason: 'manifest references missing files: $gone');
  });
}
