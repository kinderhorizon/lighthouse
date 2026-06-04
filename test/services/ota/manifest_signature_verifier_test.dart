import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/ota/manifest_signature_verifier.dart';

/// Generates an Ed25519 keypair and returns (base64 public key, sign function).
Future<({String publicKeyB64, SimpleKeyPair keyPair})> _newKey() async {
  final algo = Ed25519();
  final keyPair = await algo.newKeyPair();
  final pub = await keyPair.extractPublicKey();
  return (publicKeyB64: base64.encode(pub.bytes), keyPair: keyPair);
}

Future<List<int>> _sign(SimpleKeyPair keyPair, List<int> message) async {
  final sig = await Ed25519().sign(message, keyPair: keyPair);
  return sig.bytes;
}

void main() {
  final manifest = utf8.encode('{"schemaVersion":1,"contentVersion":"v1"}');

  test('accepts a signature made by a trusted key', () async {
    final k = await _newKey();
    final sig = await _sign(k.keyPair, manifest);
    final v = ManifestSignatureVerifier(trustedPublicKeysBase64: [k.publicKeyB64]);
    expect(await v.verify(manifestBytes: manifest, signatureBytes: sig), isTrue);
  });

  test('rejects a signature from a key NOT in the trust-list', () async {
    final signer = await _newKey();
    final other = await _newKey();
    final sig = await _sign(signer.keyPair, manifest);
    final v =
        ManifestSignatureVerifier(trustedPublicKeysBase64: [other.publicKeyB64]);
    expect(await v.verify(manifestBytes: manifest, signatureBytes: sig), isFalse);
  });

  test('rejects when the manifest bytes are tampered', () async {
    final k = await _newKey();
    final sig = await _sign(k.keyPair, manifest);
    final v = ManifestSignatureVerifier(trustedPublicKeysBase64: [k.publicKeyB64]);
    final tampered = utf8.encode('{"schemaVersion":1,"contentVersion":"v2"}');
    expect(
        await v.verify(manifestBytes: tampered, signatureBytes: sig), isFalse);
  });

  test('rotation: accepts either current or next key in the trust-list',
      () async {
    final current = await _newKey();
    final next = await _newKey();
    final v = ManifestSignatureVerifier(
      trustedPublicKeysBase64: [current.publicKeyB64, next.publicKeyB64],
    );
    // Signed by the NEXT key (rotation in progress) still verifies.
    final sig = await _sign(next.keyPair, manifest);
    expect(await v.verify(manifestBytes: manifest, signatureBytes: sig), isTrue);
  });

  test('fails closed: empty trust-list', () async {
    final k = await _newKey();
    final sig = await _sign(k.keyPair, manifest);
    final v = ManifestSignatureVerifier(trustedPublicKeysBase64: []);
    expect(await v.verify(manifestBytes: manifest, signatureBytes: sig), isFalse);
  });

  test('fails closed: empty / garbage signature', () async {
    final k = await _newKey();
    final v = ManifestSignatureVerifier(trustedPublicKeysBase64: [k.publicKeyB64]);
    expect(await v.verify(manifestBytes: manifest, signatureBytes: const []),
        isFalse);
    expect(
      await v.verify(
          manifestBytes: manifest, signatureBytes: Uint8List.fromList([1, 2, 3])),
      isFalse,
    );
  });

  test('fails closed: malformed key in the trust-list is skipped', () async {
    final k = await _newKey();
    final sig = await _sign(k.keyPair, manifest);
    final v = ManifestSignatureVerifier(
      trustedPublicKeysBase64: ['not-base64!!', 'AAAA', k.publicKeyB64],
    );
    // The valid key still wins despite garbage entries.
    expect(await v.verify(manifestBytes: manifest, signatureBytes: sig), isTrue);
  });
}
