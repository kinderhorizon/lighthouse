import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

/// A minimal in-memory bundle so the engine can be exercised without the
/// Flutter asset machinery or any platform audio plugin.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._byKey);

  final Map<String, String> _byKey;

  @override
  Future<ByteData> load(String key) async {
    final value = _byKey[key];
    if (value == null) {
      throw Exception('asset not found: $key');
    }
    return ByteData.view(Uint8List.fromList(utf8.encode(value)).buffer);
  }
}

String _manifest(List<Map<String, String>> clips) => jsonEncode({
      'schema_version': '1.0',
      'format': 'audio/mpeg',
      'clips': clips,
    });

BundledAudioTTSEngine _engineWith(String manifestJson) => BundledAudioTTSEngine(
      bundle: _FakeBundle({'assets/audio/manifest.json': manifestJson}),
    );

void main() {
  const en = Locale('en');
  const ar = Locale('ar');
  const es = Locale('es');

  test('empty manifest claims nothing', () async {
    final engine = _engineWith(_manifest(const []));
    expect(await engine.canSpeak('eye', locale: en), isFalse);
    expect(await engine.canSpeak('anything', locale: ar), isFalse);
  });

  test('canSpeak is true only for an exact (locale, voice_out) match',
      () async {
    final engine = _engineWith(_manifest([
      {'locale': 'en', 'voice_out': 'eye', 'path': 'assets/audio/en/i.mp3'},
      {
        'locale': 'ar',
        'voice_out': 'أَنَا',
        'path': 'assets/audio/ar/i.mp3',
      },
    ]));

    // Match.
    expect(await engine.canSpeak('eye', locale: en), isTrue);
    expect(await engine.canSpeak('أَنَا', locale: ar), isTrue);

    // Right text, wrong locale.
    expect(await engine.canSpeak('eye', locale: ar), isFalse);
    expect(await engine.canSpeak('eye', locale: es), isFalse);

    // Right locale, text not in the bundle (e.g. free-typed) -> falls through.
    expect(await engine.canSpeak('something typed', locale: en), isFalse);

    // Diacritics are significant: the bare Arabic label is not the voice_out.
    expect(await engine.canSpeak('أنا', locale: ar), isFalse);
  });

  test('a missing or malformed manifest degrades to claiming nothing',
      () async {
    final missing = BundledAudioTTSEngine(bundle: _FakeBundle(const {}));
    expect(await missing.canSpeak('eye', locale: en), isFalse);

    final malformed = _engineWith('{ not valid json');
    expect(await malformed.canSpeak('eye', locale: en), isFalse);
  });

  test('the fallback chain prefers a bundled clip, then system TTS', () async {
    final bundled = _engineWith(_manifest([
      {'locale': 'en', 'voice_out': 'eye', 'path': 'assets/audio/en/i.mp3'},
    ]));
    // A stand-in "system" engine that can speak anything.
    final chain = FallbackTTSEngine([bundled, _AlwaysSystem()]);

    // The chain as a whole can always speak (system backstops it).
    expect(await chain.canSpeak('eye', locale: en), isTrue);
    expect(await chain.canSpeak('free text', locale: en), isTrue);
  });
}

/// Text-agnostic stand-in for [SystemTTSEngine] (no platform channel).
class _AlwaysSystem implements TTSEngine {
  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async => true;
  @override
  Future<void> speak(String text, {required Locale locale}) async {}
  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
