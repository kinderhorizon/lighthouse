/// HTTP seam for OTA fetches (ADR 0017).
///
/// This is the ONLY runtime outbound network surface in the app. Per the
/// binding guardrail: HTTPS-only, against the KHF content endpoint, carrying at
/// most an app-version string and NOTHING about the child or usage (no device
/// id, no analytics rider). Abstracted behind an interface so the update
/// service is testable without real network.
library;

import 'package:http/http.dart' as http;

class ContentHttpException implements Exception {
  const ContentHttpException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ContentHttpException${statusCode != null ? '($statusCode)' : ''}: $message';
}

abstract class ContentHttpClient {
  /// GETs [url] and returns the body bytes. Throws [ContentHttpException] on a
  /// non-HTTPS url, a non-2xx status, a transport error, or a body that exceeds
  /// [maxBytes] (defaults to a coarse ceiling). The cap matters because the
  /// manifest fetch happens BEFORE signature verification, so a compromised or
  /// buggy CDN must not be able to OOM the device with an unbounded body.
  Future<List<int>> getBytes(String url, {int? maxBytes});
}

class HttpContentClient implements ContentHttpClient {
  HttpContentClient({required this.appVersion, http.Client? client})
      : _client = client ?? http.Client();

  /// The only app-specific data sent (binding guardrail): a version string so
  /// the server can serve content this build can render. Never a device id,
  /// usage, or anything about the child.
  final String appVersion;

  final http.Client _client;

  /// Per-request ceiling so a stalled CDN cannot hang the voluntary update
  /// check (which blocks the parent on the "Check for updates" screen).
  static const Duration _timeout = Duration(seconds: 20);

  /// Coarse default body ceiling (8 MiB) when the caller has no exact expected
  /// size. The manifest + signature have no declared size so they use this;
  /// content files pass their manifest-declared `bytes` for an exact bound.
  static const int _defaultMaxBytes = 8 * 1024 * 1024;

  @override
  Future<List<int>> getBytes(String url, {int? maxBytes}) async {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') {
      throw ContentHttpException('refusing non-HTTPS url: $url');
    }
    final cap = maxBytes ?? _defaultMaxBytes;
    try {
      return await _readCapped(uri, cap).timeout(_timeout);
    } on ContentHttpException {
      rethrow; // status / size errors are already well-formed; do not re-wrap.
    } catch (e) {
      // A timeout surfaces here as a TimeoutException; treated as a transport
      // error so a hung request cannot block the check forever.
      throw ContentHttpException('transport error: $e');
    }
  }

  /// Streams the response and accumulates with a running cap, so an oversized
  /// body is rejected WITHOUT first buffering the whole thing into memory
  /// (the OOM vector of reading `response.bodyBytes` unbounded). A declared
  /// Content-Length over the cap is rejected up front as a cheap fast-path.
  Future<List<int>> _readCapped(Uri uri, int cap) async {
    final req = http.Request('GET', uri)
      ..headers['X-Lighthouse-App-Version'] = appVersion
      // Minimal, non-identifying UA: do not leak device model / build meta.
      ..headers['User-Agent'] = 'Lighthouse-OTA';
    final res = await _client.send(req);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ContentHttpException('unexpected status',
          statusCode: res.statusCode);
    }
    final declared = res.contentLength;
    if (declared != null && declared > cap) {
      throw ContentHttpException(
          'response too large: declared $declared > $cap bytes');
    }
    final bytes = <int>[];
    await for (final chunk in res.stream) {
      bytes.addAll(chunk);
      if (bytes.length > cap) {
        throw ContentHttpException('response too large: exceeded $cap bytes');
      }
    }
    return bytes;
  }
}
