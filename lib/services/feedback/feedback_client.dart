/// Feedback submission client (ADR 0018).
///
/// POSTs a [FeedbackSubmission] as JSON to the KHF feedback endpoint (an Azure
/// Function relay; deploy deferred). HTTPS-only. This and the OTA fetch are the
/// app's only outbound surfaces; both share the HTTPS-only / no-extra-PII
/// discipline. The endpoint re-validates everything server-side; this client
/// just reports the outcome.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'feedback_submission.dart';

enum FeedbackSendResult {
  /// 2xx: the relay accepted it.
  sent,

  /// No endpoint configured (deploy deferred): a clean no-op.
  notConfigured,

  /// Client-side validation failed (empty message, bad email, too long).
  invalid,

  /// 4xx: the server rejected it (bad payload / rate-limited).
  rejected,

  /// Non-HTTPS url, transport error, or 5xx. The typed draft is not lost.
  networkError,
}

class FeedbackClient {
  FeedbackClient({required this.endpointUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Empty/null means feedback is not configured yet (deploy deferred).
  final String? endpointUrl;

  final http.Client _client;

  /// Per-request ceiling so a stalled endpoint cannot hang the Send button.
  static const Duration _timeout = Duration(seconds: 20);

  Future<FeedbackSendResult> send(FeedbackSubmission submission) async {
    if (submission.validationError() != null) {
      return FeedbackSendResult.invalid;
    }
    final url = endpointUrl;
    if (url == null || url.isEmpty) return FeedbackSendResult.notConfigured;
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') return FeedbackSendResult.networkError;
    try {
      final res = await _client
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'User-Agent': 'Lighthouse-Feedback',
            },
            body: jsonEncode(submission.toJson()),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return FeedbackSendResult.sent;
      }
      if (res.statusCode >= 400 && res.statusCode < 500) {
        return FeedbackSendResult.rejected;
      }
      return FeedbackSendResult.networkError;
    } catch (_) {
      return FeedbackSendResult.networkError;
    }
  }
}
