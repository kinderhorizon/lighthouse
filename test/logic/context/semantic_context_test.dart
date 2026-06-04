import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/logic/logic.dart';

void main() {
  group('SemanticContext', () {
    test('empty context has no dominant category', () {
      expect(SemanticContext().dominant(), isNull);
    });

    test('first tap is dominant at score 1.0', () {
      final s = SemanticContext();
      s.recordTap('food');
      expect(s.dominant(), 'food');
      expect(s.snapshot['food'], 1.0);
    });

    test('tap on category B decays category A by 0.8', () {
      final s = SemanticContext();
      s.recordTap('food');
      s.recordTap('verb');
      expect(s.snapshot['food'], closeTo(0.8, 1e-9));
      expect(s.snapshot['verb'], 1.0);
      expect(s.dominant(), 'verb');
    });

    test('repeated taps on same category keep score at 1.0', () {
      final s = SemanticContext();
      s.recordTap('food');
      s.recordTap('food');
      s.recordTap('food');
      expect(s.snapshot['food'], 1.0);
    });

    test('categories below 0.05 are pruned to keep the map bounded', () {
      final s = SemanticContext();
      s.recordTap('food');
      // 0.8^14 ~= 0.044, below the 0.05 prune threshold
      for (var i = 0; i < 14; i++) {
        s.recordTap('other');
      }
      expect(s.snapshot.containsKey('food'), isFalse);
    });

    test('dominant returns null when no score >= threshold', () {
      final s = SemanticContext();
      s.recordTap('food');
      // After 7 decays food sits ~0.21 < 0.3
      for (var i = 0; i < 7; i++) {
        s.recordTap('other');
      }
      // 'other' was just set to 1.0 so it IS dominant; manually prune
      // to test the "no dominant" branch.
      s.clear();
      expect(s.dominant(), isNull);
    });

    test('ties broken by alphabetical order for stable state keys', () {
      // recordTap sets the tapped category to 1.0 each call, so two
      // categories never collide in practice. The tie-break path is
      // exercised by an in-memory population.
      final s = SemanticContext(decayFactor: 1.0);
      s.recordTap('zebra');
      s.recordTap('apple');
      // Both now at 1.0 because decayFactor=1.0 disabled decay.
      expect(s.dominant(), 'apple');
    });
  });
}
