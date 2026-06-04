/// Utterance (sentence bar) provider (ADR 0010).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/state/state.dart';

AACButton _b(String id, {String type = 'word'}) {
  return AACButton.fromJson({
    'id': id,
    'label': id,
    'type': type,
    'voice_out': id,
    'position': {'row': 0, 'col': 0},
    'category': 'word',
  });
}

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts empty', () {
    expect(container.read(utteranceProvider), isEmpty);
  });

  test('append adds a word token in order', () {
    final n = container.read(utteranceProvider.notifier);
    n.append(_b('want'));
    n.append(_b('apple'));
    expect(
      container.read(utteranceProvider).map((b) => b.id).toList(),
      ['want', 'apple'],
    );
  });

  test('append ignores folder buttons (navigation is not communication)', () {
    final n = container.read(utteranceProvider.notifier);
    n.append(_b('food', type: 'folder'));
    expect(container.read(utteranceProvider), isEmpty);
  });

  test('backspace removes the last token, no-op when empty', () {
    final n = container.read(utteranceProvider.notifier);
    n.backspace(); // no throw on empty
    n.append(_b('want'));
    n.append(_b('apple'));
    n.backspace();
    expect(
      container.read(utteranceProvider).map((b) => b.id).toList(),
      ['want'],
    );
  });

  test('clear empties the sentence', () {
    final n = container.read(utteranceProvider.notifier);
    n.append(_b('want'));
    n.append(_b('apple'));
    n.clear();
    expect(container.read(utteranceProvider), isEmpty);
  });

  group('commit (word accumulates; phrase/folder never enter the bar)', () {
    test('commit of a word appends like append', () {
      final n = container.read(utteranceProvider.notifier);
      n.commit(_b('i'));
      n.commit(_b('want'));
      expect(
        container.read(utteranceProvider).map((b) => b.id).toList(),
        ['i', 'want'],
      );
    });

    test('a phrase never appends (no run-on) and never clears '
        'in-progress words (review NEW-D)', () {
      final n = container.read(utteranceProvider.notifier);
      n.commit(_b('i'));
      n.commit(_b('want'));
      // A phrase button ("I need to go to the bathroom") is a complete utterance
      // spoken on tap; it must neither run on with the words nor wipe them.
      n.commit(_b('bathroom', type: 'phrase'));
      expect(
        container.read(utteranceProvider).map((b) => b.id).toList(),
        ['i', 'want'],
        reason: 'phrase leaves the half-built sentence untouched',
      );

      // A phrase tapped with an empty bar likewise leaves it empty (it spoke
      // on tap), so following words never run on into it.
      n.clear();
      n.commit(_b('bathroom', type: 'phrase'));
      n.commit(_b('water'));
      expect(
        container.read(utteranceProvider).map((b) => b.id).toList(),
        ['water'],
      );
    });

    test('commit ignores folder buttons', () {
      final n = container.read(utteranceProvider.notifier);
      n.commit(_b('food', type: 'folder'));
      expect(container.read(utteranceProvider), isEmpty);
    });
  });
}
