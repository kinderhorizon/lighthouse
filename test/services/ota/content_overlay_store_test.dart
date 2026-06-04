import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/ota/content_manifest.dart';
import 'package:lighthouse/services/ota/content_overlay_store.dart';

void main() {
  late Directory tmp;
  late ContentOverlayStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('overlay_store_test_');
    store = ContentOverlayStore(dirOverride: tmp);
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('empty store: nothing applied, every path resolves to null (bundled)',
      () async {
    final state = await store.readState();
    expect(state.isEmpty, isTrue);
    expect(await store.overlayFileFor('boards/board_body.json'), isNull);
  });

  test('apply then resolve returns the overlaid file with the right bytes',
      () async {
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {
        'boards/board_body.json': utf8.encode('{"board":"body-v1"}'),
        'audio/en/abc.mp3': [1, 2, 3],
      },
    );
    final state = await store.readState();
    expect(state.activeVersion, 'v1');
    expect(state.files, containsAll(<String>['boards/board_body.json', 'audio/en/abc.mp3']));

    final board = await store.overlayFileFor('boards/board_body.json');
    expect(board, isNotNull);
    expect(await board!.readAsString(), '{"board":"body-v1"}');

    // A path not in the manifest resolves to null (bundled).
    expect(await store.overlayFileFor('boards/board_food.json'), isNull);
  });

  test('applying a new version activates it but RETAINS the prior as '
      'last-known-good; an older-than-prior is GCd', () async {
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {'boards/x.json': utf8.encode('v1')},
    );
    await store.apply(
      contentVersion: 'v2',
      sequence: 2,
      files: {'boards/x.json': utf8.encode('v2')},
    );
    expect((await store.readState()).activeVersion, 'v2');
    expect(await (await store.overlayFileFor('boards/x.json'))!.readAsString(),
        'v2');
    // seq 1 is RETAINED as the rollback target (not GCd immediately). Dirs are
    // named by sequence, not contentVersion.
    expect(Directory('${tmp.path}/content_overlay/v/1').existsSync(), isTrue);
    expect(Directory('${tmp.path}/content_overlay/v/2').existsSync(), isTrue);
    // A third apply keeps {seq 3, seq 2} and GCs seq 1 (older than the prior).
    await store.apply(
      contentVersion: 'v3',
      sequence: 3,
      files: {'boards/x.json': utf8.encode('v3')},
    );
    expect(Directory('${tmp.path}/content_overlay/v/1').existsSync(), isFalse);
    expect(Directory('${tmp.path}/content_overlay/v/2').existsSync(), isTrue);
    expect(Directory('${tmp.path}/content_overlay/v/3').existsSync(), isTrue);
  });

  test('rollback reverts to the immediately-prior version (last-known-good)',
      () async {
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {'boards/x.json': utf8.encode('v1')},
    );
    await store.apply(
      contentVersion: 'v2',
      sequence: 2,
      files: {'boards/x.json': utf8.encode('v2')},
    );
    expect((await store.readState()).activeVersion, 'v2');

    expect(await store.rollback(), isTrue);
    final s = await store.readState();
    expect(s.activeVersion, 'v1');
    expect(s.sequence, 1);
    expect(await (await store.overlayFileFor('boards/x.json'))!.readAsString(),
        'v1');

    // Single-level: nothing further to roll back to.
    expect(await store.rollback(), isFalse);
  });

  test('a new version REUSING a prior contentVersion string does not destroy '
      'the active dir (sequence-keyed, review #2)', () async {
    // The bug this guards: dirs were named by contentVersion, so a higher-
    // sequence manifest that reused a version string would delete-recursive
    // the currently-active dir during the write window, leaving the board to
    // fall back to bundled until the pointer flipped. Keyed on sequence, the
    // two applies land in distinct dirs and never collide.
    await store.apply(
      contentVersion: 'dup',
      sequence: 1,
      files: {'boards/x.json': utf8.encode('first')},
    );
    await store.apply(
      contentVersion: 'dup', // SAME string, higher sequence
      sequence: 2,
      files: {'boards/x.json': utf8.encode('second')},
    );
    // Distinct dirs by sequence; the first survived the second's write.
    expect(Directory('${tmp.path}/content_overlay/v/1').existsSync(), isTrue);
    expect(Directory('${tmp.path}/content_overlay/v/2').existsSync(), isTrue);
    expect((await store.readState()).sequence, 2);
    expect(await (await store.overlayFileFor('boards/x.json'))!.readAsString(),
        'second');
    // Rollback recovers the first version's content even though the two share
    // the contentVersion string (it is located by sequence).
    expect(await store.rollback(), isTrue);
    expect(await (await store.overlayFileFor('boards/x.json'))!.readAsString(),
        'first');
  });

  test('apply rejects a non-positive sequence (defense in depth)', () async {
    for (final bad in [0, -1]) {
      expect(
        () => store.apply(
            contentVersion: 'v1', sequence: bad, files: {'boards/x.json': [1]}),
        throwsA(isA<ContentManifestException>()),
        reason: 'sequence $bad must be rejected at apply',
      );
    }
  });

  test('rollback is a no-op when nothing has been applied', () async {
    expect(await store.rollback(), isFalse);
  });

  test('clear reverts to bundled (resolves null)', () async {
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {'boards/x.json': utf8.encode('v1')},
    );
    await store.clear();
    expect((await store.readState()).isEmpty, isTrue);
    expect(await store.overlayFileFor('boards/x.json'), isNull);
  });

  test('atomic: a pointer naming a version with no file on disk resolves null',
      () async {
    // Simulate a corrupt/half state: pointer says v9 but no files were written.
    final root = Directory('${tmp.path}/content_overlay')..createSync(recursive: true);
    File('${root.path}/pointer.json').writeAsStringSync(
        jsonEncode({'activeVersion': 'v9', 'files': ['boards/x.json']}));
    expect(await store.overlayFileFor('boards/x.json'), isNull);
  });

  test('corrupt pointer.json is treated as nothing-applied, not an error',
      () async {
    final root = Directory('${tmp.path}/content_overlay')..createSync(recursive: true);
    File('${root.path}/pointer.json').writeAsStringSync('{not json');
    expect((await store.readState()).isEmpty, isTrue);
    expect(await store.overlayFileFor('boards/x.json'), isNull);
  });

  test('apply rejects an unsafe content path', () async {
    expect(
      () => store.apply(
          contentVersion: 'v1', sequence: 1, files: {'../escape': [1]}),
      throwsA(isA<ContentManifestException>()),
    );
  });

  test('apply rejects an unsafe contentVersion (defense in depth)', () async {
    for (final bad in ['..', '../evil', 'a/b', 'has space']) {
      expect(
        () => store.apply(
            contentVersion: bad,
            sequence: 1,
            files: {'boards/x.json': [1]}),
        throwsA(isA<ContentManifestException>()),
        reason: 'contentVersion "$bad" must be rejected at apply',
      );
    }
  });
}
