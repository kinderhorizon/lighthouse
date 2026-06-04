/// Regression for review M4: the OTA fetch must bound the response size so a
/// compromised/buggy CDN cannot OOM the device (the manifest is read BEFORE
/// signature verification). `getBytes` streams with a running cap instead of
/// buffering an unbounded `bodyBytes`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lighthouse/services/ota/content_http_client.dart';

http.StreamedResponse _streamed(
  List<List<int>> chunks, {
  int status = 200,
  int? contentLength,
}) =>
    http.StreamedResponse(Stream.fromIterable(chunks), status,
        contentLength: contentLength);

void main() {
  test('refuses a non-HTTPS url', () async {
    final c = HttpContentClient(
      appVersion: '1',
      client: MockClient((_) async => http.Response('', 200)),
    );
    expect(() => c.getBytes('http://insecure/x'),
        throwsA(isA<ContentHttpException>()));
  });

  test('returns the body when under the cap', () async {
    final client = MockClient.streaming(
        (req, body) async => _streamed([
              [1, 2, 3]
            ], contentLength: 3));
    final c = HttpContentClient(appVersion: '1', client: client);
    expect(await c.getBytes('https://ota/x', maxBytes: 10), [1, 2, 3]);
  });

  test('rejects a body that exceeds maxBytes while streaming (no full buffer)',
      () async {
    // contentLength omitted, so the running-cap path (not the declared-length
    // fast path) is what trips: two 4-byte chunks exceed a 5-byte cap.
    final client = MockClient.streaming((req, body) async => _streamed([
          List.filled(4, 0),
          List.filled(4, 0),
        ]));
    final c = HttpContentClient(appVersion: '1', client: client);
    expect(() => c.getBytes('https://ota/x', maxBytes: 5),
        throwsA(isA<ContentHttpException>()));
  });

  test('rejects an over-declared Content-Length up front', () async {
    final client = MockClient.streaming(
        (req, body) async => _streamed([], contentLength: 999));
    final c = HttpContentClient(appVersion: '1', client: client);
    expect(() => c.getBytes('https://ota/x', maxBytes: 10),
        throwsA(isA<ContentHttpException>()));
  });

  test('maps a non-2xx status to ContentHttpException', () async {
    final client =
        MockClient.streaming((req, body) async => _streamed([], status: 503));
    final c = HttpContentClient(appVersion: '1', client: client);
    expect(() => c.getBytes('https://ota/x'),
        throwsA(isA<ContentHttpException>()));
  });

  test('sends only the marketing version in X-Lighthouse-App-Version (ADR 0021)',
      () async {
    // HIGH-1: the build number must NEVER reach the wire. Even though the app
    // forms a combined "0.1.0+8" identity for the local targetVersion gate, the
    // client is constructed with the marketing version alone, and the header
    // must carry exactly that, never the combined identity.
    String? sentVersion;
    final client = MockClient.streaming((req, body) async {
      sentVersion = req.headers['X-Lighthouse-App-Version'];
      return _streamed([
        [1]
      ], contentLength: 1);
    });
    final c = HttpContentClient(appVersion: '0.1.0', client: client);
    await c.getBytes('https://ota/x', maxBytes: 10);
    expect(sentVersion, '0.1.0');
    expect(sentVersion, isNot(contains('+')));
  });
}
