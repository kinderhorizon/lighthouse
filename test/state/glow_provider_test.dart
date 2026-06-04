/// Unit tests for the pure mapping inside the glow provider.
///
/// The Riverpod plumbing itself (stateKey composition, board watching,
/// contextEpoch invalidation, ranker invocation) is exercised by the
/// integration_test/persistence_test.dart against a real Isar + WiFi
/// stub, where the full async chain runs to completion on a device.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/state/glow_provider.dart';

AACButton _btn(String id, {String category = 'needs'}) => AACButton(
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

RankedPrediction _pred({
  required String id,
  required double posteriorMean,
  required int observationCount,
  String category = 'needs',
}) =>
    RankedPrediction(
      button: _btn(id, category: category),
      draw: posteriorMean,
      posteriorMean: posteriorMean,
      observationCount: observationCount,
    );

void main() {
  group('buildGlowMap', () {
    test('omits buttons whose level computes to none', () {
      final map = buildGlowMap([
        _pred(id: 'low', posteriorMean: 0.10, observationCount: 0),
        _pred(id: 'gold', posteriorMean: 0.90, observationCount: 0),
      ]);
      expect(map.containsKey('low'), isFalse);
      expect(map['gold'], GlowLevel.gold);
    });

    test('maps shimmer band correctly at cold start', () {
      final map = buildGlowMap([
        _pred(id: 'sh', posteriorMean: 0.55, observationCount: 0),
      ]);
      // At obs=0: gold>=0.75, shimmer>=0.50. 0.55 is shimmer.
      expect(map['sh'], GlowLevel.shimmer);
    });

    test('uses observation-count-aware thresholds for deep predictions',
        () {
      // Same posterior mean 0.60: glow at obs=11 (>=0.60 gold), shimmer
      // at obs=4 (gold=0.65 not met, shimmer=0.35 met), none at obs=0
      // (gold=0.75 not met, shimmer=0.50 met -> still shimmer at 0.60).
      expect(
        buildGlowMap(
            [_pred(id: 'a', posteriorMean: 0.60, observationCount: 11)]),
        {'a': GlowLevel.gold},
      );
      expect(
        buildGlowMap(
            [_pred(id: 'a', posteriorMean: 0.60, observationCount: 4)]),
        {'a': GlowLevel.shimmer},
      );
      expect(
        buildGlowMap(
            [_pred(id: 'a', posteriorMean: 0.60, observationCount: 0)]),
        {'a': GlowLevel.shimmer},
      );
    });

    test('empty input yields empty map', () {
      expect(buildGlowMap(const []), isEmpty);
    });
  });

  group('buildGlowMap semantic boost (ADR 0011)', () {
    AACBoard boardWith(List<Map<String, dynamic>> buttons) {
      // Assign each button a distinct in-grid position by index. The glow logic
      // keys on id/category, not position; unique positions just satisfy the
      // board schema (AACBoard.fromJson rejects duplicate/out-of-grid cells).
      final placed = [
        for (final (i, btn) in buttons.indexed)
          {...btn, 'position': {'row': i ~/ 8, 'col': i % 8}},
      ];
      return AACBoard.fromJson({
        'schema_version': '1.0',
        'board_id': 'b',
        'grid_dimensions': [7, 8],
        'color_key': {},
        'buttons': placed,
      });
    }

    Map<String, dynamic> b(String id, String category,
            {String type = 'word'}) =>
        {
          'id': id,
          'label': id,
          'type': type,
          'voice_out': id,
          'category': category,
        };

    test('after "eat" the Food folder is force-glowed gold (folders can glow)',
        () {
      final board = boardWith([
        b('btn_eat', 'verb'),
        b('btn_food_folder', 'food_nav', type: 'folder'),
        b('btn_play', 'verb'),
      ]);
      final map = buildGlowMap(
        const [],
        board: board,
        lastTokenId: 'btn_eat',
      );
      expect(map['btn_food_folder'], GlowLevel.gold);
    });

    test('"eat" boosts food but NOT water; "drink" boosts water (clinical review)',
        () {
      // Water carries the `drink` category, so "eat water" is no longer
      // suggested in English (clinical review), while "drink water" still is.
      final board = boardWith([
        b('btn_eat', 'verb'),
        b('btn_drink', 'verb'),
        b('btn_water', 'drink'),
        b('btn_food_folder', 'food_nav', type: 'folder'),
      ]);

      final afterEat =
          buildGlowMap(const [], board: board, lastTokenId: 'btn_eat');
      expect(afterEat['btn_food_folder'], GlowLevel.gold);
      expect(afterEat.containsKey('btn_water'), isFalse,
          reason: 'eat must not light up water in English');

      final afterDrink =
          buildGlowMap(const [], board: board, lastTokenId: 'btn_drink');
      expect(afterDrink['btn_water'], GlowLevel.gold);
    });

    test('no boost for a verb without an object domain (want -> bandit)', () {
      final board = boardWith([
        b('btn_want', 'verb'),
        b('btn_food_folder', 'food_nav', type: 'folder'),
      ]);
      final map = buildGlowMap(
        const [],
        board: board,
        lastTokenId: 'btn_want',
      );
      expect(map, isEmpty); // falls through to the (empty) bandit ranking
    });

    test('defers to the bandit when already inside the target sub-board', () {
      // A board that is mostly food items: boosting > max of them is noise,
      // so the boost backs off and the bandit ranking (here, one shimmer)
      // stands.
      final board = boardWith([
        for (var i = 0; i < 8; i++) b('btn_food_$i', 'food'),
      ]);
      final map = buildGlowMap(
        [_pred(id: 'btn_food_3', posteriorMean: 0.55, observationCount: 0)],
        board: board,
        lastTokenId: 'btn_eat',
      );
      expect(map, {'btn_food_3': GlowLevel.shimmer});
    });

    test('no board or no last token leaves the bandit map untouched', () {
      final ranked = [_pred(id: 'x', posteriorMean: 0.9, observationCount: 0)];
      expect(buildGlowMap(ranked), {'x': GlowLevel.gold});
      expect(buildGlowMap(ranked, lastTokenId: 'btn_eat'), {'x': GlowLevel.gold});
    });
  });

  group('post-verb category suppression (clinical review)', () {
    List<RankedPrediction> ranked() => [
          _pred(
              id: 'btn_yes',
              category: 'response',
              posteriorMean: 0.9,
              observationCount: 0),
          _pred(
              id: 'btn_happy',
              category: 'feeling',
              posteriorMean: 0.9,
              observationCount: 0),
          _pred(
              id: 'btn_go',
              category: 'verb',
              posteriorMean: 0.9,
              observationCount: 0),
          _pred(
              id: 'btn_water',
              category: 'food',
              posteriorMean: 0.9,
              observationCount: 0),
        ];

    test('after "want", responses/feelings are dropped; verbs/nouns kept', () {
      final map = buildGlowMap(ranked(), lastTokenId: 'btn_want');
      expect(map.containsKey('btn_yes'), isFalse, reason: 'no "want yes"');
      expect(map.containsKey('btn_happy'), isFalse, reason: 'no "want happy"');
      expect(map['btn_go'], GlowLevel.gold);
      expect(map['btn_water'], GlowLevel.gold);
    });

    test('without a transitive verb, nothing is suppressed', () {
      // After "eat" (an object-boost verb, not a transitive light verb) the
      // suppression does not apply; yes/happy survive the base ranking.
      final map = buildGlowMap(ranked(), lastTokenId: 'btn_eat');
      expect(map.containsKey('btn_yes'), isTrue);
      expect(map.containsKey('btn_happy'), isTrue);
    });
  });
}
