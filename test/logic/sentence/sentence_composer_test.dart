/// Sentence composition (ADR 0010).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';

AACButton _b(
  String voiceOut, {
  String category = 'word',
  String type = 'word',
  Map<String, String> localized = const {},
}) {
  return AACButton.fromJson({
    'id': 'btn_${voiceOut.replaceAll(' ', '_')}',
    'label': voiceOut,
    'type': type,
    'voice_out': voiceOut,
    'position': {'row': 0, 'col': 0},
    'category': category,
    for (final e in localized.entries) 'voice_out_${e.key}': e.value,
  });
}

void main() {
  test('empty token list composes to empty string', () {
    expect(composeUtterance(const [], 'en'), '');
  });

  test('a single word is capitalized', () {
    expect(composeUtterance([_b('want', category: 'verb')], 'en'), 'Want');
  });

  test('words join with spaces, first capitalized', () {
    final tokens = [
      _b('I', category: 'pronoun'),
      _b('want', category: 'verb'),
      _b('apple', category: 'food'),
    ];
    expect(composeUtterance(tokens, 'en'), 'I want apple');
  });

  test('English inserts "to" between two consecutive verbs (item #7)', () {
    final tokens = [
      _b('want', category: 'verb'),
      _b('go', category: 'verb'),
    ];
    expect(composeUtterance(tokens, 'en'), 'Want to go');
  });

  test('"to" is NOT inserted between a verb and a non-verb', () {
    final tokens = [
      _b('want', category: 'verb'),
      _b('apple', category: 'food'),
    ];
    expect(composeUtterance(tokens, 'en'), 'Want apple');
  });

  test('the "to" rule is English-only (no "to" in Spanish)', () {
    final tokens = [
      _b('want',
          category: 'verb', localized: {'es': 'quiero'}),
      _b('go', category: 'verb', localized: {'es': 'ir'}),
    ];
    expect(composeUtterance(tokens, 'es'), 'Quiero ir');
  });

  test('localized voice-out is used for the active locale', () {
    final tokens = [
      _b('water', category: 'food', localized: {'es': 'agua'}),
    ];
    expect(composeUtterance(tokens, 'es'), 'Agua');
  });

  test('composeUtteranceTokens returns the ordered word list with "to"', () {
    final tokens = [
      _b('want', category: 'verb'),
      _b('go', category: 'verb'),
    ];
    // The list form (fed to speakSequence) carries the inserted "to" but is
    // NOT capitalized: capitalization is audio-irrelevant and the bundled
    // engine concatenates per-word clips keyed on the raw voice_out.
    expect(composeUtteranceTokens(tokens, 'en'), ['want', 'to', 'go']);
  });

  test('composeUtteranceTokens is empty for no tokens', () {
    expect(composeUtteranceTokens(const [], 'en'), isEmpty);
  });

  test('folder tokens are ignored defensively', () {
    final tokens = [
      _b('want', category: 'verb'),
      _b('food', type: 'folder', category: 'food_nav'),
      _b('apple', category: 'food'),
    ];
    // A folder carries no voice_out anyway, but guard the type explicitly.
    expect(composeUtterance(tokens, 'en'), 'Want apple');
  });
}
