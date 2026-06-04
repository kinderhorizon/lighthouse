/// In-app feedback submission model (ADR 0018).
///
/// User-initiated egress (the parent types something and taps Send), the same
/// privacy category as crash-log / vocab-pack sharing. The payload carries ONLY
/// what is declared here: the chosen category, the typed message, an optional
/// contact email, and low-entropy triage context (app version, OS version,
/// locale). NEVER the child, the board, usage, logs, or any finer device
/// metadata (no device model / identifiers). The server re-validates everything
/// (client validation here is UX-only).
library;

import 'dart:math';

enum FeedbackCategory {
  bug,
  suggestion,
  other;

  String toJson() => name;
}

/// Client-side message length cap (the server enforces its own). Generous
/// enough for a detailed report, bounded to keep the payload small.
const int kFeedbackMessageMaxLength = 4000;

class FeedbackSubmission {
  const FeedbackSubmission({
    required this.category,
    required this.message,
    required this.appVersion,
    required this.osVersion,
    required this.locale,
    required this.clientNonce,
    this.contactEmail,
  });

  final FeedbackCategory category;
  final String message;

  /// Optional, only if the parent wants a reply.
  final String? contactEmail;

  final String appVersion;
  final String osVersion;
  final String locale;

  /// Per-SUBMISSION random correlation id (e.g. a support reference that can be
  /// echoed in the forwarded email). NOT a dedup/replay guarantee: the
  /// persist-nothing relay (ADR 0018) keeps no state to dedup against, so the
  /// nonce is inert there and only gains meaning if transient server state is
  /// ever added. MUST stay per-submission random, never per-install (a stable
  /// value would be an identifier).
  final String clientNonce;

  Map<String, dynamic> toJson() => {
        'category': category.toJson(),
        'message': message,
        if (contactEmail != null && contactEmail!.isNotEmpty)
          'contactEmail': contactEmail,
        'appVersion': appVersion,
        'osVersion': osVersion,
        'locale': locale,
        'clientNonce': clientNonce,
      };

  /// Client-side (UX-only) validity: a non-empty, length-capped message and, if
  /// given, a plausible email. Returns null when valid, else a short reason key.
  String? validationError() {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return 'empty';
    if (message.length > kFeedbackMessageMaxLength) return 'tooLong';
    final email = contactEmail;
    if (email != null && email.isNotEmpty && !_looksLikeEmail(email)) {
      return 'badEmail';
    }
    return null;
  }

  static bool _looksLikeEmail(String s) {
    // Deliberately permissive: a real check is server-side. Just catches
    // obvious typos before sending.
    final at = s.indexOf('@');
    return at > 0 && s.indexOf('.', at) > at + 1 && !s.contains(' ');
  }
}

/// A fresh, cryptographically-random per-submission nonce (hex). Generated once
/// per Send, never persisted as an install identifier.
String newClientNonce() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
