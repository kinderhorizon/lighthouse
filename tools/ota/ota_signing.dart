/// OTA signing primitives (ADR 0017), shared by the keygen and signer CLIs.
///
/// Pulled out of the CLI wrappers so the keygen -> sign -> verify round-trip
/// can be tested against the app's real [ManifestSignatureVerifier] (see
/// test/tools/ota_signing_test.dart). That test is the guarantee the tooling
/// stays byte-compatible with the app: if the on-device verifier ever changes
/// what it accepts, the round-trip breaks here first.
///
/// Ed25519, matching the verifier: a 32-byte seed is the private key, the
/// 32-byte public key is what goes in `kOtaTrustedPublicKeys`, and the detached
/// signature is the raw 64 bytes over the EXACT manifest.json bytes that get
/// uploaded. The private key seed lives ONLY on the offline publishing machine,
/// never in the repo, the app, or Azure.
library;

import 'package:cryptography/cryptography.dart';

/// A freshly generated Ed25519 key pair, as raw bytes.
class OtaKeyPair {
  const OtaKeyPair({required this.seed, required this.publicKey});

  /// 32-byte private seed. Keep offline. Reconstructs the pair via
  /// [signManifestBytes].
  final List<int> seed;

  /// 32-byte public key. Add (base64) to `kOtaTrustedPublicKeys`.
  final List<int> publicKey;
}

/// Generates a new Ed25519 key pair.
Future<OtaKeyPair> generateKeyPair() async {
  final keyPair = await Ed25519().newKeyPair();
  final seed = await keyPair.extractPrivateKeyBytes();
  final publicKey = await keyPair.extractPublicKey();
  return OtaKeyPair(seed: seed, publicKey: publicKey.bytes);
}

/// Signs [manifestBytes] (the exact bytes that will be served as manifest.json)
/// with the Ed25519 private [seed]. Returns the raw detached signature bytes
/// to write as manifest.json.sig. Throws [ArgumentError] on a malformed seed.
Future<List<int>> signManifestBytes(
  List<int> seed,
  List<int> manifestBytes,
) async {
  if (seed.length != 32) {
    throw ArgumentError('Ed25519 seed must be 32 bytes, got ${seed.length}');
  }
  final keyPair = await Ed25519().newKeyPairFromSeed(seed);
  final signature = await Ed25519().sign(manifestBytes, keyPair: keyPair);
  return signature.bytes;
}
