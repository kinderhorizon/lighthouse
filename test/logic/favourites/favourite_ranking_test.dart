/// Favourite-candidate ranking (ADR 0013).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';

ButtonRef _r(String id, [String board = 'b']) =>
    (boardId: board, buttonId: id);

void main() {
  test('ranks by descending frequency', () {
    final taps = [
      _r('a'), _r('b'), _r('a'), _r('c'), _r('a'), _r('b'),
    ];
    expect(rankByFrequency(taps, limit: 3), [_r('a'), _r('b'), _r('c')]);
  });

  test('respects the limit', () {
    final taps = [_r('a'), _r('b'), _r('c')];
    expect(rankByFrequency(taps, limit: 2), hasLength(2));
  });

  test('ties keep first-seen order (deterministic)', () {
    final taps = [_r('x'), _r('y')]; // both count 1
    expect(rankByFrequency(taps, limit: 2), [_r('x'), _r('y')]);
  });

  test('empty input yields empty', () {
    expect(rankByFrequency(const [], limit: 5), isEmpty);
  });

  test('same id on different boards are distinct refs', () {
    final taps = [_r('a', 'b1'), _r('a', 'b2'), _r('a', 'b1')];
    expect(rankByFrequency(taps, limit: 1), [_r('a', 'b1')]);
  });
}
