/// Guided tour state machine (ADR 0020).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/tour/tour_controller.dart';

void main() {
  test('there are exactly 7 steps (all on Home)', () {
    expect(kTourSteps.length, 7);
    // No step targets a screen other than Home: board / sentence / arrange /
    // settings. The two app-bar buttons (arrange + settings) get distinct steps.
    for (final s in kTourSteps) {
      expect(s.target, isNot(TourTarget.none),
          reason: 'every step spotlights a real Home control');
    }
    expect(kTourSteps.map((s) => s.target), contains(TourTarget.arrange));
    expect(kTourSteps.map((s) => s.target), contains(TourTarget.settings));
  });

  test('start / next / back / finish transitions', () {
    final c = TourController();
    expect(c.state.active, isFalse);

    c.start();
    expect(c.state.active, isTrue);
    expect(c.state.index, 0);
    expect(c.state.isFirst, isTrue);

    c.next();
    expect(c.state.index, 1);
    c.back();
    expect(c.state.index, 0);
    c.back(); // no-op at first
    expect(c.state.index, 0);

    // Walk to the last step.
    for (var i = 0; i < kTourSteps.length - 1; i++) {
      c.next();
    }
    expect(c.state.isLast, isTrue);
    expect(c.state.index, kTourSteps.length - 1);

    // Next on the last step finishes (stops) the tour.
    c.next();
    expect(c.state.active, isFalse);
  });

  test('stop ends the tour and resets the index', () {
    final c = TourController()..start();
    c
      ..next()
      ..next();
    c.stop();
    expect(c.state.active, isFalse);
    expect(c.state.index, 0);
  });
}
