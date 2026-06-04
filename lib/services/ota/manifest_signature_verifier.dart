/// OTA manifest signature verification (ADR 0017).
///
/// sha256-in-the-manifest proves a file matches the manifest, NOT that the
/// manifest is authentic. Because the OTA channel changes what a non-speaking
/// child's board says, a compromised blob/CDN or MITM serving a
/// malicious-but-internally-consistent manifest must NOT be trusted. So the
/// manifest carries a detached Ed25519 signature, verified here against a
/// bundled **trust-list** of public keys.
///
/// The trust-list (current + next key) is what makes key rotation non-breaking:
/// an installed app accepts a manifest signed by ANY trusted key, so a new key
/// can be rolled out before the old one is retired. The private key lives ONLY
/// in the publish pipeline, never in the app and never in Azure.
///
/// Fails CLOSED: an empty trust-list, an empty/garbage signature, or no
/// matching key all return false. We never apply unverified content.
library;

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class ManifestSignatureVerifier {
  ManifestSignatureVerifier({required this.trustedPublicKeysBase64})
      : _algorithm = Ed25519();

  /// Base64-encoded 32-byte Ed25519 public keys the app will accept (current +
  /// next, for rotation). Bundled with the app.
  final List<String> trustedPublicKeysBase64;

  final Ed25519 _algorithm;

  /// Ed25519 public keys are exactly 32 bytes.
  static const int _ed25519PublicKeyBytes = 32;

  /// Returns true iff [signatureBytes] is a valid Ed25519 signature of
  /// [manifestBytes] under ANY key in the trust-list. Fails closed.
  Future<bool> verify({
    required List<int> manifestBytes,
    required List<int> signatureBytes,
  }) async {
    if (trustedPublicKeysBase64.isEmpty || signatureBytes.isEmpty) {
      return false;
    }
    for (final encoded in trustedPublicKeysBase64) {
      try {
        final keyBytes = base64.decode(encoded.trim());
        if (keyBytes.length != _ed25519PublicKeyBytes) continue;
        final publicKey =
            SimplePublicKey(keyBytes, type: KeyPairType.ed25519);
        final signature = Signature(signatureBytes, publicKey: publicKey);
        if (await _algorithm.verify(manifestBytes, signature: signature)) {
          return true;
        }
      } catch (_) {
        // Malformed key or signature for this candidate: try the next one.
        // Overall result stays false unless some key cleanly verifies.
        continue;
      }
    }
    return false;
  }
}
