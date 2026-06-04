/// Localization completeness guards (ADR 0008).
///
/// These tests iterate the locale registry; they never name a locale. Adding
/// a language to LocaleRegistry automatically extends their coverage, and a
/// missing ARB key or board translation fails CI rather than silently
/// shipping an English fallback in a non-English build.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/i18n/locale_registry.dart';

Map<String, dynamic> _readArb(String code) {
  final file = File('lib/l10n/app_$code.arb');
  if (!file.existsSync()) {
    throw StateError('every registered locale needs lib/l10n/app_$code.arb');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Message keys only: drop ICU metadata (@key) and the @@locale marker.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Every button across every board under boards/ (core + sub-boards), so the
/// completeness guards cover the whole app, not just the home board.
List<Map<String, dynamic>> _allBoardButtons() {
  final out = <Map<String, dynamic>>[];
  for (final f in Directory('boards')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))) {
    final b = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    out.addAll((b['buttons'] as List).cast<Map<String, dynamic>>());
  }
  return out;
}

void main() {
  test('English template exists and is the registry default', () {
    expect(LocaleRegistry.specForCode('en'), isNotNull);
    expect(LocaleRegistry.fallback, const Locale('en'));
    expect(File('lib/l10n/app_en.arb').existsSync(), isTrue);
  });

  final templateKeys = _messageKeys(_readArb('en'));

  test('template is non-trivial (guards an empty-ARB false pass)', () {
    expect(templateKeys.length, greaterThan(30));
  });

  // ARB parity: forall registered locale, keys(en) subset of keys(locale).
  for (final spec in LocaleRegistry.all) {
    test('ARB ${spec.code} covers every English key', () {
      final localeKeys = _messageKeys(_readArb(spec.code));
      final missing = templateKeys.difference(localeKeys);
      expect(missing, isEmpty,
          reason: 'app_${spec.code}.arb is missing keys: $missing');
    });
  }

  group('board name localization', () {
    // Every board's display name (shown in the AppBar) must be translated for
    // each non-default locale via board_name_<code>, or an Arabic/Spanish
    // family sees the English title.
    final boardFiles = Directory('boards')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)
        .toList();

    for (final spec in LocaleRegistry.all.where((s) => s.code != 'en')) {
      test('every board has a ${spec.code} board_name', () {
        final missing = <String>[];
        for (final b in boardFiles) {
          final v = b['board_name_${spec.code}'];
          if (v is! String || v.trim().isEmpty) {
            missing.add(b['board_id'] as String);
          }
        }
        expect(missing, isEmpty,
            reason: 'boards missing board_name_${spec.code}: $missing');
      });
    }
  });

  group('board vocabulary completeness', () {
    final buttons = _allBoardButtons();

    bool isFolder(Map<String, dynamic> b) =>
        b['type'] == 'folder' || b['voice_out'] == null;

    // Skip the registry default (en is the source language carried in the
    // bare `label` / `voice_out` fields).
    final nonDefault =
        LocaleRegistry.all.where((s) => s.code != 'en').toList();

    for (final spec in nonDefault) {
      test('every button has a ${spec.code} label', () {
        final missing = <String>[];
        for (final b in buttons) {
          final v = b['label_${spec.code}'];
          if (v is! String || v.trim().isEmpty) missing.add(b['id'] as String);
        }
        expect(missing, isEmpty,
            reason: 'buttons missing label_${spec.code}: $missing');
      });

      test('every speaking button has a ${spec.code} voice_out', () {
        final missing = <String>[];
        for (final b in buttons) {
          if (isFolder(b)) continue;
          final v = b['voice_out_${spec.code}'];
          if (v is! String || v.trim().isEmpty) missing.add(b['id'] as String);
        }
        expect(missing, isEmpty,
            reason: 'speaking buttons missing voice_out_${spec.code}: '
                '$missing');
      });
    }
  });

  group('locale resolution (registry-driven)', () {
    final supported = LocaleRegistry.supportedLocales;

    for (final spec in LocaleRegistry.all) {
      test('${spec.code} resolves to itself', () {
        expect(LocaleRegistry.resolve(spec.locale, supported), spec.locale);
      });
    }

    test('unsupported locale falls back to the registry default', () {
      expect(LocaleRegistry.resolve(const Locale('de'), supported),
          LocaleRegistry.fallback);
      expect(LocaleRegistry.resolve(null, supported),
          LocaleRegistry.fallback);
    });

    test('region is ignored; language code is matched', () {
      expect(LocaleRegistry.resolve(const Locale('ar', 'EG'), supported),
          const Locale('ar'));
    });
  });

  // Bundled-audio TTS coverage (ADR 0004 amendment). The set of locales that
  // get pre-rendered clips is the registry's ttsStrategy == bundledClips set;
  // this is what tools/tts/generate_clips.dart renders. A clip can only exist
  // for a word that has a voice_out, so every bundled locale must have full
  // voice_out coverage on the board, or the render would have silent gaps.
  group('bundled-audio coverage (registry ttsStrategy-driven)', () {
    final buttons = _allBoardButtons();

    bool isFolder(Map<String, dynamic> b) =>
        b['type'] == 'folder' || b['voice_out'] == null;

    String? voiceOutFor(Map<String, dynamic> b, String code) =>
        code == 'en' ? b['voice_out'] as String? : b['voice_out_$code'] as String?;

    final bundled = LocaleRegistry.all
        .where((s) => s.ttsStrategy == TtsStrategy.bundledClips)
        .toList();

    test('at least one locale is bundled (guards a false pass)', () {
      expect(bundled, isNotEmpty);
    });

    for (final spec in bundled) {
      test('${spec.code} has a voice_out for every speaking button', () {
        final missing = <String>[];
        for (final b in buttons) {
          if (isFolder(b)) continue;
          final v = voiceOutFor(b, spec.code);
          if (v is! String || v.trim().isEmpty) missing.add(b['id'] as String);
        }
        expect(missing, isEmpty,
            reason: 'bundled locale ${spec.code} cannot be fully rendered; '
                'buttons missing voice_out: $missing');
      });
    }
  });
}
