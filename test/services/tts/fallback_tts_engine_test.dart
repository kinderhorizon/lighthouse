/// FallbackTTSEngine routing (ADR 0010 / ADR 0008).
///
/// The load-bearing case is the sentence-replay routing fixed for clinical review: a
/// token without a bundled clip (the inserted English "to" connector) must fall
/// through to system TTS for THAT WORD ONLY, never dumping the whole sentence to
/// the robotic system voice.
library;

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

/// Records what it was asked to speak, and only claims tokens in [known].
class _FakeEngine implements TTSEngine {
  _FakeEngine(this.name, this.known);

  final String name;
  final Set<String> known;
  final List<String> spokenSequence = [];

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async =>
      known.contains(text);

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    spokenSequence.add(text);
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    spokenSequence.addAll(texts);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  const locale = Locale('en');

  test('each token routes to the first engine that can speak it', () async {
    final bundled = _FakeEngine('bundled', {'want', 'go'});
    final system = _FakeEngine('system', {'want', 'to', 'go'});
    final fallback = FallbackTTSEngine([bundled, system]);

    await fallback.speakSequence(['want', 'to', 'go'], locale: locale);

    // Real words stay on the bundled (warm) engine...
    expect(bundled.spokenSequence, ['want', 'go']);
    // ...only the clip-less connector "to" falls through to system TTS.
    expect(system.spokenSequence, ['to']);
  });

  test('a fully-covered sentence never touches the fallback engine', () async {
    final bundled = _FakeEngine('bundled', {'eye', 'want', 'water'});
    final system = _FakeEngine('system', {'eye', 'want', 'water'});
    final fallback = FallbackTTSEngine([bundled, system]);

    await fallback.speakSequence(['eye', 'want', 'water'], locale: locale);

    expect(bundled.spokenSequence, ['eye', 'want', 'water']);
    expect(system.spokenSequence, isEmpty);
  });

  test('order is preserved across mixed-engine tokens', () async {
    final bundled = _FakeEngine('bundled', {'a', 'c'});
    final system = _FakeEngine('system', {'a', 'b', 'c'});
    final fallback = FallbackTTSEngine([bundled, system]);

    await fallback.speakSequence(['a', 'b', 'c'], locale: locale);

    expect(bundled.spokenSequence, ['a', 'c']);
    expect(system.spokenSequence, ['b']);
  });
}
