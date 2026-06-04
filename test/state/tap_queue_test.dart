/// [SerialQueue] is the shared FIFO that both tap persistence and sentence-bar
/// edits run through, so a delete's context revert can never be overwritten by a
/// still-draining tap record (the "delete to [I, Want] but glow stays on the
/// deleted word" bug).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/state/state.dart';

void main() {
  group('SerialQueue', () {
    test('runs tasks in enqueue order even when an earlier task is slow', () async {
      final q = SerialQueue();
      final order = <String>[];

      // Mimics a slow, still-draining tap record enqueued first...
      final tap = q.add(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        order.add('tap');
      });
      // ...then a delete revert enqueued right after. It MUST run last.
      final revert = q.add(() async {
        order.add('revert');
      });

      await Future.wait([tap, revert]);
      expect(order, ['tap', 'revert']);
    });

    test('a failing task does not poison tasks queued behind it', () async {
      final q = SerialQueue();
      final ran = <String>[];

      final bad = q.add(() async => throw StateError('boom'));
      final good = q.add(() async => ran.add('after'));

      // The failing task's future rejects, but the queue keeps draining.
      await expectLater(bad, throwsStateError);
      await good;
      expect(ran, ['after']);
    });
  });
}
