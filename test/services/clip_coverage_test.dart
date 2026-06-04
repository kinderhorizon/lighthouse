/// Bundled-audio coverage guard.
///
/// Bundled clips are the PRIMARY speech path (docs/adr/0004 amendment). When a
/// word button has no clip for the active locale, the engine falls through to
/// system TTS, which on many devices (especially for Arabic) is robotic or
/// silent. For a non-speaking child a silent tap is the worst failure, so core
/// vocabulary coverage must be total, per locale, and verified at build time.
///
/// The right invariant is BUTTON-LEVEL, not a clip-count equality across
/// locales: legitimate within-locale homophones (English "I" and "eye" both
/// voice out "eye"; Spanish "afternoon" and "late" both "tarde") make the
/// unique-text counts differ between locales while coverage is still complete.
/// So we assert, for every non-folder button and every shipped locale:
///   1. the per-locale voice_out field is present (no silent fall-back to the
///      English string, which would never match a non-English clip), and
///   2. the resolved (locale, voice_out) has a clip in the manifest.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Locales we ship clips for, read from the manifest's own voice map so this
  // tracks the rendered set rather than a hard-coded list.
  final audioManifest = jsonDecode(
    File('assets/audio/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final locales = (audioManifest['voices'] as Map<String, dynamic>).keys.toList();
  final clips =
      (audioManifest['clips'] as List).cast<Map<String, dynamic>>();
  final available = {
    for (final c in clips) '${c['locale']} ${c['voice_out']}',
  };

  final words = <Map<String, dynamic>>[];
  for (final f in Directory('boards')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))) {
    final board = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    for (final btn in (board['buttons'] as List).cast<Map<String, dynamic>>()) {
      if (btn['type'] == 'folder') continue;
      words.add(btn);
    }
  }

  test('every word button has a per-locale voice_out for each shipped locale',
      () {
    final missing = <String>[];
    for (final btn in words) {
      for (final loc in locales) {
        if (loc == 'en') continue; // default voice_out is the English form
        if (btn['voice_out_$loc'] == null) {
          missing.add('${btn['id']} (voice_out_$loc)');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'a missing per-locale voice_out resolves to the English string '
            'at runtime, which never matches a non-English clip: $missing');
  });

  test('every word button resolves to a bundled clip in every shipped locale',
      () {
    final absent = <String>[];
    for (final btn in words) {
      for (final loc in locales) {
        final text = loc == 'en'
            ? btn['voice_out'] as String?
            : (btn['voice_out_$loc'] ?? btn['voice_out']) as String?;
        if (text == null || !available.contains('$loc $text')) {
          absent.add('${btn['id']}[$loc]=${text ?? '<null>'}');
        }
      }
    }
    expect(absent, isEmpty,
        reason: 'these buttons would fall back to system TTS (robotic/silent): '
            '$absent');
  });
}
