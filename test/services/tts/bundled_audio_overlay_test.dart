import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('audio_overlay_');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('an OTA-overlaid clip resolves to the overlay file (ADR 0017)', () async {
    final store = ContentOverlayStore(dirOverride: tmp);
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {
        'audio/en/abc.mp3': [1, 2, 3]
      },
    );
    final engine = BundledAudioTTSEngine(contentOverlay: store);
    final p = await engine.overlayClipFilePathFor('assets/audio/en/abc.mp3');
    expect(p, isNotNull);
    expect(await File(p!).readAsBytes(), [1, 2, 3]);
  });

  test('a clip with no overlay resolves to null (bundled asset is used)',
      () async {
    final engine = BundledAudioTTSEngine(
      contentOverlay: ContentOverlayStore(dirOverride: tmp),
    );
    expect(
      await engine.overlayClipFilePathFor('assets/audio/en/abc.mp3'),
      isNull,
    );
  });

  test('no overlay store at all resolves to null', () async {
    final engine = BundledAudioTTSEngine();
    expect(
      await engine.overlayClipFilePathFor('assets/audio/en/abc.mp3'),
      isNull,
    );
  });
}
