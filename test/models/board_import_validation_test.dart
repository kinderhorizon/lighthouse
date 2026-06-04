/// Import-hardening validation for AACBoard / AACButton (review finding).
///
/// An imported board is untrusted. These pin the bounds that keep a crafted or
/// malformed pack from crashing or hanging the app: bounded grid, in-grid and
/// unique positions, unique ids, finite/bounded weights, bounded text, and a
/// safe icon URI. Bundled boards satisfy all of these (covered elsewhere).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';

Map<String, dynamic> _btn(
  String id, {
  int row = 0,
  int col = 0,
  Object? baseWeight,
  String? iconUri,
  String? label,
}) =>
    {
      'id': id,
      'label': label ?? id,
      'type': 'word',
      'voice_out': id,
      'position': {'row': row, 'col': col},
      'category': 'noun',
      if (baseWeight != null) 'base_weight': baseWeight,
      if (iconUri != null) 'icon_uri': iconUri,
    };

Map<String, dynamic> _board(
  List<Map<String, dynamic>> buttons, {
  List<int> grid = const [7, 8],
}) =>
    {
      'schema_version': '1.0',
      'board_id': 'b',
      'grid_dimensions': grid,
      'color_key': {},
      'buttons': buttons,
    };

void main() {
  group('grid bounds', () {
    for (final grid in [
      [0, 8],
      [7, 0],
      [-1, 8],
      [65, 8],
      [8, 65],
    ]) {
      test('rejects out-of-range grid $grid', () {
        expect(() => AACBoard.fromJson(_board([_btn('a')], grid: grid)),
            throwsFormatException);
      });
    }

    test('accepts the bundled-style 7x8 grid', () {
      expect(AACBoard.fromJson(_board([_btn('a')])).gridDimensions,
          (rows: 7, cols: 8));
    });
  });

  group('button placement', () {
    test('rejects a button outside the grid', () {
      expect(() => AACBoard.fromJson(_board([_btn('a', row: 7, col: 0)])),
          throwsFormatException);
    });

    test('rejects a negative position', () {
      expect(() => AACBoard.fromJson(_board([_btn('a', row: -1)])),
          throwsFormatException);
    });

    test('rejects two buttons sharing a position', () {
      expect(
          () => AACBoard.fromJson(
              _board([_btn('a', row: 0, col: 0), _btn('b', row: 0, col: 0)])),
          throwsFormatException);
    });

    test('rejects duplicate button ids', () {
      expect(
          () => AACBoard.fromJson(
              _board([_btn('dup', row: 0, col: 0), _btn('dup', row: 0, col: 1)])),
          throwsFormatException);
    });
  });

  group('button field bounds', () {
    // base_weight is a Bernoulli mean; the only valid range is [0, 1]. The
    // 1.0001/1.5/2.0 cases pin the tightened ceiling (was 1e6, which admitted
    // the whole (1, 1e6] NaN-producing band): the old 1e9 case threw under
    // both ceilings, so its green gave false confidence that out-of-range was
    // handled while the dangerous band sailed through.
    for (final w in [double.nan, double.infinity, -1, 1.0001, 1.5, 2.0, 1e9]) {
      test('rejects out-of-range base_weight $w', () {
        expect(() => AACButton.fromJson(_btn('a', baseWeight: w)),
            throwsFormatException);
      });
    }

    // The endpoints 0.0 and 1.0 are accepted at parse (consistent with how 0.0
    // was already allowed); the cold-start prior clamp, not the parse bound, is
    // what keeps them from forming a degenerate alpha/beta.
    for (final w in [0.0, 1.0]) {
      test('accepts endpoint base_weight $w', () {
        expect(AACButton.fromJson(_btn('a', baseWeight: w)).baseWeight, w);
      });
    }

    test('rejects an over-long label', () {
      expect(
          () => AACButton.fromJson(
              _btn('a', label: 'x' * (kMaxButtonTextLength + 1))),
          throwsFormatException);
    });

    for (final uri in ['../escape.png', r'a\b.png', 'x' * (kMaxIconUriLength + 1)]) {
      test('rejects unsafe icon_uri "${uri.length > 30 ? '<long>' : uri}"', () {
        expect(() => AACButton.fromJson(_btn('a', iconUri: uri)),
            throwsFormatException);
      });
    }

    test('accepts a normal asset icon_uri and weight', () {
      final b = AACButton.fromJson(
          _btn('a', iconUri: 'assets/pictograms/cup.png', baseWeight: 0.7));
      expect(b.iconUri, 'assets/pictograms/cup.png');
      expect(b.baseWeight, 0.7);
    });

    test('rejects an over-long voice_out', () {
      final j = _btn('a')..['voice_out'] = 'x' * (kMaxButtonTextLength + 1);
      expect(() => AACButton.fromJson(j), throwsFormatException);
    });

    test('rejects an over-long per-locale label value', () {
      final j = _btn('a')..['label_es'] = 'x' * (kMaxButtonTextLength + 1);
      expect(() => AACButton.fromJson(j), throwsFormatException);
    });

    test('rejects an over-long category', () {
      final j = _btn('a')..['category'] = 'x' * (kMaxButtonTextLength + 1);
      expect(() => AACButton.fromJson(j), throwsFormatException);
    });
  });
}
