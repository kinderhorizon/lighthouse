import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/ota/content_http_client.dart';
import 'package:lighthouse/services/ota/content_manifest.dart';
import 'package:lighthouse/services/ota/content_overlay_store.dart';
import 'package:lighthouse/services/ota/content_update_service.dart';
import 'package:lighthouse/services/ota/manifest_signature_verifier.dart';

class _FakeHttp implements ContentHttpClient {
  _FakeHttp(this.responses);
  final Map<String, List<int>> responses;
  @override
  Future<List<int>> getBytes(String url, {int? maxBytes}) async {
    final b = responses[url];
    if (b == null) throw const ContentHttpException('404', statusCode: 404);
    return b;
  }
}

const _base = 'https://ota.example/content';

void main() {
  late Directory tmp;
  late ContentOverlayStore store;
  late SimpleKeyPair keyPair;
  late String publicKeyB64;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('update_service_');
    store = ContentOverlayStore(dirOverride: tmp);
    keyPair = await Ed25519().newKeyPair();
    publicKeyB64 = base64.encode((await keyPair.extractPublicKey()).bytes);
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// Builds a signed manifest + the served files. Returns (responses, manifest).
  Future<Map<String, List<int>>> _serve({
    required String version,
    required Map<String, List<int>> files,
    int sequence = 1,
    String? minAppVersion,
    String? targetVersion,
    bool corruptOneFile = false,
  }) async {
    final entries = files.entries
        .map((e) => {
              'path': e.key,
              'sha256': sha256.convert(e.value).toString(),
              'bytes': e.value.length,
            })
        .toList();
    final manifestJson = jsonEncode({
      'schemaVersion': 1,
      'sequence': sequence,
      'contentVersion': version,
      if (minAppVersion != null) 'minAppVersion': minAppVersion,
      if (targetVersion != null) 'targetVersion': targetVersion,
      'files': entries,
    });
    final manifestBytes = utf8.encode(manifestJson);
    final sig = await Ed25519().sign(manifestBytes, keyPair: keyPair);
    final responses = <String, List<int>>{
      '$_base/manifest.json': manifestBytes,
      '$_base/manifest.json.sig': sig.bytes,
      for (final e in files.entries)
        '$_base/${e.key}': corruptOneFile ? [...e.value, 0] : e.value,
    };
    return responses;
  }

  ContentUpdateService _service(
    Map<String, List<int>> responses, {
    String appVersion = '1.0.0',
    String appBuild = '',
    List<String>? trust,
    String? baseUrl = _base,
  }) =>
      ContentUpdateService(
        baseUrl: baseUrl,
        appVersion: appVersion,
        appBuild: appBuild,
        httpClient: _FakeHttp(responses),
        store: store,
        verifier: ManifestSignatureVerifier(
          trustedPublicKeysBase64: trust ?? [publicKeyB64],
        ),
      );

  test('available -> apply downloads, verifies, and applies the overlay',
      () async {
    final responses = await _serve(
      version: 'v1',
      files: {'boards/core_main.json': utf8.encode('{"board":"v1"}')},
    );
    final svc = _service(responses);

    final check = await svc.check();
    expect(check.status, UpdateStatus.available);
    expect(check.manifest, isNotNull);

    await svc.apply(check.manifest!);
    expect((await store.readState()).activeVersion, 'v1');
    final f = await store.overlayFileFor('boards/core_main.json');
    expect(await f!.readAsString(), '{"board":"v1"}');
  });

  test('upToDate when the applied version already matches', () async {
    await store.apply(
      contentVersion: 'v1',
      sequence: 1,
      files: {'boards/core_main.json': utf8.encode('{"board":"v1"}')},
    );
    final responses = await _serve(
      version: 'v1',
      sequence: 1,
      files: {'boards/core_main.json': utf8.encode('{"board":"v1"}')},
    );
    expect((await _service(responses).check()).status, UpdateStatus.upToDate);
  });

  test('downgrade attack: a validly-signed OLDER manifest is refused (ADR 0017)',
      () async {
    // Applied sequence 2.
    await store.apply(
      contentVersion: 'v2',
      sequence: 2,
      files: {'boards/x.json': utf8.encode('v2')},
    );
    // Server replays a correctly-signed sequence-1 manifest.
    final responses = await _serve(
      version: 'v1',
      sequence: 1,
      files: {'boards/x.json': utf8.encode('v1')},
    );
    final svc = _service(responses);
    // check() treats a non-newer manifest as upToDate (never offered to apply).
    expect((await svc.check()).status, UpdateStatus.upToDate);
    // apply() refuses outright, and the applied content stays at v2.
    final older = ContentManifest.parse(
        utf8.decode(responses['$_base/manifest.json']!));
    await expectLater(
        svc.apply(older), throwsA(isA<ContentManifestException>()));
    expect((await store.readState()).activeVersion, 'v2');
  });

  test('signature verification failure -> error, nothing applied', () async {
    final responses = await _serve(
      version: 'v1',
      files: {'boards/x.json': utf8.encode('x')},
    );
    // Trust a DIFFERENT key than the one that signed.
    final other = base64.encode(
        (await (await Ed25519().newKeyPair()).extractPublicKey()).bytes);
    final check = await _service(responses, trust: [other]).check();
    expect(check.status, UpdateStatus.error);
    expect((await store.readState()).isEmpty, isTrue);
  });

  test('sha256 mismatch on apply throws and does not apply', () async {
    final responses = await _serve(
      version: 'v1',
      files: {'boards/x.json': utf8.encode('x')},
      corruptOneFile: true,
    );
    final svc = _service(responses);
    final check = await svc.check();
    expect(check.status, UpdateStatus.available);
    await expectLater(
        svc.apply(check.manifest!), throwsA(isA<ContentManifestException>()));
    expect((await store.readState()).isEmpty, isTrue);
  });

  test('incompatible when minAppVersion exceeds the app version', () async {
    final responses = await _serve(
      version: 'v1',
      files: {'boards/x.json': utf8.encode('x')},
      minAppVersion: '2.0.0',
    );
    final check = await _service(responses, appVersion: '1.5.0').check();
    expect(check.status, UpdateStatus.incompatible);
  });

  test('a suffixed minAppVersion orders by its numeric part', () async {
    // minAppVersion 1.5.1-rc1 exceeds app 1.5.0, so the update is incompatible.
    // Before the leading-digit fix, "1-rc1" parsed as 0, making 1.5.1-rc1 read
    // as EQUAL to 1.5.0 and the update wrongly compatible.
    final responses = await _serve(
      version: 'v1',
      files: {'boards/x.json': utf8.encode('x')},
      minAppVersion: '1.5.1-rc1',
    );
    final check = await _service(responses, appVersion: '1.5.0').check();
    expect(check.status, UpdateStatus.incompatible);
  });

  test('notConfigured when baseUrl is empty (deploy deferred)', () async {
    final check = await _service(const {}, baseUrl: '').check();
    expect(check.status, UpdateStatus.notConfigured);
  });

  test('http error (missing manifest) -> error', () async {
    final check = await _service(const {}).check();
    expect(check.status, UpdateStatus.error);
  });

  group('targetVersion release-version gate (ADR 0021)', () {
    Future<Map<String, List<int>>> serveTagged(String? targetVersion) => _serve(
          version: 'v1',
          sequence: 1,
          targetVersion: targetVersion,
          files: {'boards/x.json': utf8.encode('v1')},
        );

    test('null targetVersion + newer sequence -> available (pre-0021 behavior)',
        () async {
      final svc = _service(await serveTagged(null),
          appVersion: '0.1.0', appBuild: '7');
      expect((await svc.check()).status, UpdateStatus.available);
    });

    test('device build below target + newer sequence -> available', () async {
      final svc = _service(await serveTagged('0.1.0+8'),
          appVersion: '0.1.0', appBuild: '7');
      expect((await svc.check()).status, UpdateStatus.available);
    });

    test('device build EQUAL to target -> upToDate (fresh install of the fold)',
        () async {
      // The core fix: build 8 already bundles the correction, so even though the
      // live manifest sequence is newer than a fresh install's applied 0, it is
      // NOT offered.
      final svc = _service(await serveTagged('0.1.0+8'),
          appVersion: '0.1.0', appBuild: '8');
      expect((await svc.check()).status, UpdateStatus.upToDate);
    });

    test('device build ABOVE target -> upToDate', () async {
      final svc = _service(await serveTagged('0.1.0+8'),
          appVersion: '0.1.0', appBuild: '9');
      expect((await svc.check()).status, UpdateStatus.upToDate);
    });

    test('later marketing version outranks target despite lower build', () async {
      // Robust to an iOS build-number reset on a marketing bump.
      final svc = _service(await serveTagged('0.1.0+8'),
          appVersion: '0.2.0', appBuild: '1');
      expect((await svc.check()).status, UpdateStatus.upToDate);
    });

    test('targetVersion never overrides the sequence guard', () async {
      // Applied sequence 1 already; a manifest at sequence 1 is not newer, so it
      // stays upToDate regardless of a targetVersion the device is below.
      await store.apply(
        contentVersion: 'v1',
        sequence: 1,
        files: {'boards/x.json': utf8.encode('v1')},
      );
      final svc = _service(await serveTagged('0.1.0+8'),
          appVersion: '0.1.0', appBuild: '7');
      expect((await svc.check()).status, UpdateStatus.upToDate);
    });
  });

  group('compareAppVersion (ADR 0021)', () {
    test('build number breaks a version tie', () {
      expect(compareAppVersion('0.1.0+7', '0.1.0+8'), lessThan(0));
      expect(compareAppVersion('0.1.0+8', '0.1.0+8'), 0);
      expect(compareAppVersion('0.1.0+9', '0.1.0+8'), greaterThan(0));
    });

    test('marketing version dominates the build number', () {
      // 0.2.0+1 is a LATER release than 0.1.0+8 (build reset on marketing bump).
      expect(compareAppVersion('0.2.0+1', '0.1.0+8'), greaterThan(0));
    });

    test('missing / empty / non-numeric build all collapse to 0', () {
      expect(compareAppVersion('0.1.0', '0.1.0+0'), 0);
      expect(compareAppVersion('0.1.0+', '0.1.0+0'), 0); // empty after '+'
      expect(compareAppVersion('0.1.0+rc1', '0.1.0+0'), 0); // non-numeric -> 0
    });

    test('does not throw on a garbage build segment', () {
      expect(() => compareAppVersion('0.1.0+!!', '0.1.0+8'), returnsNormally);
    });
  });
}
