import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';

void main() {
  test('AACBoard.toJson is an exact inverse of fromJson (ADR 0015)', () {
    final raw = jsonDecode(File('test/fixtures/core_main.json').readAsStringSync())
        as Map<String, dynamic>;
    final original = AACBoard.fromJson(raw);
    final roundTripped = AACBoard.fromJson(original.toJson());
    // Serializing the round-tripped board yields identical canonical JSON:
    // fromJson . toJson is the identity (ids, labels, locales, positions, ...).
    expect(roundTripped.toJson(), equals(original.toJson()));
  });

  test('AACButton.toJson preserves voice_out, link_id, and localized maps', () {
    const folder = AACButton(
      id: 'f',
      label: 'Food',
      labelByLocale: {'es': 'Comida'},
      type: AACButtonType.folder,
      position: (row: 0, col: 0),
      category: 'nav',
      baseWeight: 0.5,
      iconUri: 'assets/f.png',
      linkId: 'board_food',
    );
    const word = AACButton(
      id: 'w',
      label: 'Want',
      labelByLocale: {},
      type: AACButtonType.word,
      position: (row: 0, col: 1),
      category: 'verb',
      baseWeight: 0.7,
      iconUri: 'assets/w.png',
      voiceOut: 'want',
      voiceOutByLocale: {'es': 'quiero'},
    );

    for (final b in [folder, word]) {
      expect(AACButton.fromJson(b.toJson()).toJson(), equals(b.toJson()));
    }

    // Null fields are omitted so they parse back to null, not "".
    expect(folder.toJson().containsKey('voice_out'), isFalse);
    expect(word.toJson().containsKey('link_id'), isFalse);
    expect(folder.toJson()['link_id'], 'board_food');
    expect(folder.toJson()['label_es'], 'Comida');
    expect(word.toJson()['voice_out'], 'want');
    expect(word.toJson()['voice_out_es'], 'quiero');
  });
}
