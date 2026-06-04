import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/hitbox/hitbox_expansion.dart';

void main() {
  group('HitboxExpansion.perSideExpansion', () {
    test('none magnitude returns 0 regardless of gaps', () {
      expect(
        HitboxExpansion.perSideExpansion(
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          magnitude: HitboxMagnitude.none,
        ),
        0.0,
      );
      expect(
        HitboxExpansion.perSideExpansion(
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          magnitude: HitboxMagnitude.none,
        ),
        0.0,
      );
    });

    test('subtle uses 50% of min(gap_x, gap_y) / 2', () {
      // min(8, 12) / 2 = 4; subtle = 4 * 0.5 = 2.
      expect(
        HitboxExpansion.perSideExpansion(
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          magnitude: HitboxMagnitude.subtle,
        ),
        2.0,
      );
    });

    test('maximum uses 100% of min(gap_x, gap_y) / 2', () {
      expect(
        HitboxExpansion.perSideExpansion(
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          magnitude: HitboxMagnitude.maximum,
        ),
        4.0,
      );
    });

    test('uses the smaller of the two gaps (no anisotropic expansion)',
        () {
      // Result must be the same when we swap gap_x and gap_y.
      final a = HitboxExpansion.perSideExpansion(
        crossAxisSpacing: 6,
        mainAxisSpacing: 20,
        magnitude: HitboxMagnitude.maximum,
      );
      final b = HitboxExpansion.perSideExpansion(
        crossAxisSpacing: 20,
        mainAxisSpacing: 6,
        magnitude: HitboxMagnitude.maximum,
      );
      expect(a, b);
      expect(a, 3.0);
    });

    test('zero gap means zero expansion at any magnitude', () {
      for (final m in HitboxMagnitude.values) {
        expect(
          HitboxExpansion.perSideExpansion(
            crossAxisSpacing: 0,
            mainAxisSpacing: 12,
            magnitude: m,
          ),
          0.0,
          reason: 'magnitude=$m',
        );
      }
    });

    test('ADR 0003 invariant: two adjacent expanded hitboxes never overlap',
        () {
      // Property check across a grid of plausible gap sizes and both
      // non-none magnitudes. Two tiles separated by `gap` on one axis
      // each expand toward the other by `perSide`; total intrusion is
      // 2 * perSide and must not exceed `gap` (equality is allowed
      // because hitboxes are open intervals on the boundary).
      const gaps = [1.0, 2.5, 4.0, 8.0, 12.0, 24.0, 64.0];
      const magnitudes = [
        HitboxMagnitude.subtle,
        HitboxMagnitude.maximum,
      ];
      for (final gx in gaps) {
        for (final gy in gaps) {
          for (final m in magnitudes) {
            final perSide = HitboxExpansion.perSideExpansion(
              crossAxisSpacing: gx,
              mainAxisSpacing: gy,
              magnitude: m,
            );
            // Cross-axis adjacency check.
            expect(2 * perSide, lessThanOrEqualTo(gx + 1e-9),
                reason: 'gx=$gx gy=$gy m=$m perSide=$perSide');
            // Main-axis adjacency check.
            expect(2 * perSide, lessThanOrEqualTo(gy + 1e-9),
                reason: 'gx=$gx gy=$gy m=$m perSide=$perSide');
          }
        }
      }
    });

    test('HitboxMagnitude.tryParse round-trips, null on unknown', () {
      for (final m in HitboxMagnitude.values) {
        expect(HitboxMagnitude.tryParse(m.toJson()), m);
      }
      expect(HitboxMagnitude.tryParse('bogus'), isNull);
      expect(HitboxMagnitude.tryParse(null), isNull);
    });
  });
}
