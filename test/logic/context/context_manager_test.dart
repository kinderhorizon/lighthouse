import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';

AACButton _btn({
  required String id,
  required String category,
}) {
  return AACButton(
    id: id,
    label: id,
    labelByLocale: const {},
    type: AACButtonType.word,
    position: (row: 0, col: 0),
    category: category,
    baseWeight: 0.5,
    iconUri: '',
    voiceOut: id,
  );
}

void main() {
  group('ContextManager.currentStateKey (PRD section 3.1 format)', () {
    test('all dimensions populated', () {
      final cm = ContextManager()
        ..recordTap(_btn(id: 'btn_help', category: 'needs'));
      final key = cm.currentStateKey(
        now: DateTime(2026, 5, 28, 9, 30), // Friday 9:30 -> School
        locale: const Locale('en'),
        wifiHash: 'wifi_HOMEHASH',
      );
      expect(key,
          'School_Weekday|wifi_HOMEHASH|Prev:btn_help|Context:needs');
    });

    test('locale-aware weekend flips DayType in ar locale', () {
      final cm = ContextManager();
      final friMorning = DateTime(2026, 5, 29, 9); // Fri 9 -> School
      final en = const Locale('en');
      final ar = const Locale('ar');
      final keyEn = cm.currentStateKey(
        now: friMorning,
        locale: en,
        wifiHash: 'wifi_H',
      );
      final keyAr = cm.currentStateKey(
        now: friMorning,
        locale: ar,
        wifiHash: 'wifi_H',
      );
      expect(keyEn, contains('School_Weekday'));
      expect(keyAr, contains('School_Weekend'));
    });

    test('missing wifiHash falls back to unknownWifiFallback', () {
      final cm = ContextManager(unknownWifiFallback: 'wifi_UNKNOWN');
      final key = cm.currentStateKey(
        now: DateTime(2026, 5, 28, 10),
        locale: const Locale('en'),
      );
      expect(key, contains('|wifi_UNKNOWN|'));
    });

    test('empty wifiHash also falls back', () {
      final cm = ContextManager();
      final key = cm.currentStateKey(
        now: DateTime(2026, 5, 28, 10),
        locale: const Locale('en'),
        wifiHash: '',
      );
      expect(key, contains('|wifi_UNKNOWN|'));
    });

    test('no previous tap: Prev: segment is empty (still present)', () {
      final cm = ContextManager();
      final key = cm.currentStateKey(
        now: DateTime(2026, 5, 28, 10),
        locale: const Locale('en'),
        wifiHash: 'wifi_H',
      );
      expect(key, contains('|Prev:|'));
    });

    test('no dominant category: Context: segment is empty', () {
      final cm = ContextManager();
      final key = cm.currentStateKey(
        now: DateTime(2026, 5, 28, 10),
        locale: const Locale('en'),
        wifiHash: 'wifi_H',
      );
      expect(key, endsWith('|Context:'));
    });

    test('reset clears previousButton and semantic dominant', () {
      final cm = ContextManager()
        ..recordTap(_btn(id: 'btn_food_folder', category: 'food_nav'));
      expect(cm.previousButtonId, 'btn_food_folder');
      cm.reset();
      expect(cm.previousButtonId, isNull);
      expect(cm.semantic.dominant(), isNull);
    });

    test('recordTap updates previousButton + bumps category', () {
      final cm = ContextManager();
      cm.recordTap(_btn(id: 'btn_help', category: 'needs'));
      cm.recordTap(_btn(id: 'btn_water', category: 'food'));
      expect(cm.previousButtonId, 'btn_water');
      // 'food' was just tapped -> dominant
      expect(cm.semantic.dominant(), 'food');
    });

    test('state key is deterministic for the same inputs', () {
      final cm = ContextManager();
      cm.recordTap(_btn(id: 'btn_a', category: 'verb'));
      final now = DateTime(2026, 5, 28, 12);
      final loc = const Locale('en');
      final k1 = cm.currentStateKey(now: now, locale: loc, wifiHash: 'h');
      final k2 = cm.currentStateKey(now: now, locale: loc, wifiHash: 'h');
      expect(k1, k2);
    });
  });

  group('ContextManager.syncToSentence (sentence-bar edit rewinds context)', () {
    final eat = _btn(id: 'btn_eat', category: 'verbs');
    final apple = _btn(id: 'btn_food_apple', category: 'food');

    test('rewinds previousButton to the new last token after a delete', () {
      // Tapped Eat then Apple -> context advanced to Apple.
      final cm = ContextManager()
        ..recordTap(eat)
        ..recordTap(apple);
      expect(cm.previousButtonId, 'btn_food_apple');

      // Backspace removed Apple; the bar now holds [Eat]. Context must follow.
      cm.syncToSentence([eat]);
      expect(cm.previousButtonId, 'btn_eat');
      // Semantic rebuilt from the remaining tokens: 'verbs' (Eat) dominates.
      expect(cm.semantic.dominant(), 'verbs');
    });

    test('empty sentence rewinds to sentence start (no previous button)', () {
      final cm = ContextManager()
        ..recordTap(eat)
        ..recordTap(apple);

      cm.syncToSentence(const []);
      expect(cm.previousButtonId, isNull);
      expect(cm.semantic.dominant(), isNull);

      // The state key reflects sentence start: bare "Prev:".
      final key = cm.currentStateKey(
        now: DateTime(2026, 5, 28, 10),
        locale: const Locale('en'),
        wifiHash: 'wifi_H',
      );
      expect(key, contains('|Prev:|'));
    });

    test('last remaining token, not the deleted one, drives the state key', () {
      final cm = ContextManager()
        ..recordTap(eat)
        ..recordTap(apple);

      cm.syncToSentence([eat]);
      final key = cm.currentStateKey(
        now: DateTime(2026, 5, 28, 10),
        locale: const Locale('en'),
        wifiHash: 'wifi_H',
      );
      expect(key, contains('Prev:btn_eat'));
      expect(key, isNot(contains('btn_food_apple')));
    });
  });
}
