/// Board size tier (handoff Rule 3): the column-count-by-device-width policy
/// that keeps the board legible on phones by reducing columns and scrolling,
/// rather than shrinking tiles below the floor. The thresholds are load-bearing
/// (the 820 boundary keeps the 11" iPad on the native fill layout), so they are
/// pinned here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/board_size_tier.dart';

void main() {
  group('boardSizeTierFor (decided by shortest side, locked across rotation)', () {
    test('phones (< 600) are the phone tier', () {
      expect(boardSizeTierFor(375), BoardSizeTier.phone); // iPhone SE
      expect(boardSizeTierFor(393), BoardSizeTier.phone); // iPhone 14/15
      expect(boardSizeTierFor(430), BoardSizeTier.phone); // Pro Max
      expect(boardSizeTierFor(599.9), BoardSizeTier.phone);
    });

    test('600..819 are the small-tablet tier', () {
      expect(boardSizeTierFor(600), BoardSizeTier.smallTablet);
      expect(boardSizeTierFor(744), BoardSizeTier.smallTablet); // iPad mini
      expect(boardSizeTierFor(768), BoardSizeTier.smallTablet); // iPad 9.7
      expect(boardSizeTierFor(819.9), BoardSizeTier.smallTablet);
    });

    test('820+ are the large-tablet tier (the primary 11" iPad stays here)', () {
      expect(boardSizeTierFor(820), BoardSizeTier.largeTablet); // iPad 10th
      expect(boardSizeTierFor(834), BoardSizeTier.largeTablet); // iPad 11"
      expect(boardSizeTierFor(1024), BoardSizeTier.largeTablet); // iPad Pro 12.9
    });
  });

  group('boardSizingFor (columns + scroll, clamped to native)', () {
    test('phone: 5 columns and scrolls', () {
      final s = boardSizingFor(shortestSide: 393, nativeColumns: 8);
      expect(s.columns, 5);
      expect(s.scrolls, isTrue);
    });

    test('small tablet: 6 columns and scrolls', () {
      final s = boardSizingFor(shortestSide: 768, nativeColumns: 8);
      expect(s.columns, 6);
      expect(s.scrolls, isTrue);
    });

    test('large tablet: native columns and fills (no scroll)', () {
      final s = boardSizingFor(shortestSide: 834, nativeColumns: 8);
      expect(s.columns, 8);
      expect(s.scrolls, isFalse);
    });

    test('never invents columns beyond the board native count', () {
      // A 3-column sub-board on a phone stays 3 wide, not 5.
      final phone = boardSizingFor(shortestSide: 393, nativeColumns: 3);
      expect(phone.columns, 3);
      final small = boardSizingFor(shortestSide: 768, nativeColumns: 4);
      expect(small.columns, 4);
    });
  });
}
