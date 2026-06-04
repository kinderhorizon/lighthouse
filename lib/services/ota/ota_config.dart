/// OTA configuration (ADR 0017).
///
/// Compile-time constants so the content endpoint and the signing trust-list
/// are baked into the build (no runtime config surface to tamper with). Both
/// are empty by default, which keeps OTA fully dormant until deploy:
///   - empty base URL  -> the update service returns `notConfigured` (no-op),
///   - empty trust-list -> signature verification fails closed.
library;

/// Content root URL, e.g. `https://<cdn>/content`. Empty until the Azure
/// Blob + CDN is provisioned (deploy deferred). Set at build time:
/// `flutter build --dart-define=OTA_BASE_URL=https://...`.
const String kOtaContentBaseUrl =
    String.fromEnvironment('OTA_BASE_URL', defaultValue: '');

/// Bundled Ed25519 public-key trust-list (base64), current + next for
/// non-breaking rotation. Each entry is the PUBLIC half of a key pair generated
/// by `tools/ota/ota_keygen.dart`; the matching private seed lives offline only
/// (1Password / ~/khf-keys), never in this repo or Azure.
///
/// Shipping a key here only makes the app ACCEPT content signed by it; OTA stays
/// dormant until `kOtaContentBaseUrl` is also set, so this is safe to ship ahead
/// of the hosting. To rotate, add the next public key here, ship that build, then
/// start signing with the new seed once enough installs accept it.
const List<String> kOtaTrustedPublicKeys = <String>[
  // Generated 2026-05-31. Private seed in 1Password (KHF OTA signing key).
  'jPuJR9uN6jyDmOpQGH4iZVyvY4eslMP2Rd8QVQSp44M=',
];
