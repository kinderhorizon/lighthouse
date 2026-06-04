# OTA content publishing tools (ADR 0017)

Offline tooling to publish a signed content-correction overlay for Lighthouse.
These fix a wrong translation, voice clip, pictogram, or tile color **without an
app-store release**. The app only ever fetches an update when a parent taps
"Check for updates" in Settings, and only applies a manifest whose Ed25519
signature verifies against the trust-list bundled in the app.

All three tools are plain `dart run` (no Flutter engine needed).

## One-time: generate a signing key

```
dart run tools/ota/ota_keygen.dart --out ~/khf-keys/ota-signing.key
```

- Writes the 32-byte **private seed** (base64) to the `--out` path. This is the
  only secret in the OTA chain. Keep it offline. NEVER commit it, share it, or
  upload it to Azure. The tool refuses to write inside the repo working tree.
- Prints the base64 **public key**. Paste it into `kOtaTrustedPublicKeys` in
  `lib/services/ota/ota_config.dart` and ship that build.

### Key rotation

The trust-list holds more than one key so rotation is non-breaking: generate the
next key ahead of time, add its public key to `kOtaTrustedPublicKeys` alongside
the current one, ship that build, and only start signing with the new seed once
enough installs accept it. Then drop the old public key in a later build.

## Each publish

1. Assemble the **overlay** directory: only the corrected files, each at its
   content-root-relative path (e.g. `boards/core_main.json`,
   `audio/en/0007.mp3`). Not the whole catalog.

2. Build the manifest (bump `--sequence` every time; it must strictly increase):

   ```
   dart run tools/ota/build_manifest.dart \
     --content ./ota-content \
     --content-version 2026.05.31 \
     --sequence 3 \
     --prev ./last-published/manifest.json   # asserts the bump
   ```

3. Sign the exact emitted bytes:

   ```
   dart run tools/ota/sign_manifest.dart \
     --manifest ./ota-content/manifest.json \
     --key ~/khf-keys/ota-signing.key \
     --public-key <base64-from-kOtaTrustedPublicKeys>   # self-check
   ```

4. Upload `manifest.json`, `manifest.json.sig`, and every listed file to the
   content host, preserving relative paths, then set `kOtaContentBaseUrl` in a
   shipped build so the "Check for updates" entry appears.

## Why `sequence` matters

The device refuses any manifest whose `sequence` is `<=` the applied one. That
blocks a downgrade/rollback attack: a validly-signed OLD manifest, replayed by a
stale cache or an attacker, cannot roll a child's board back to withdrawn
content even though its signature checks out. `--prev` catches a stale number at
authoring time so it never reaches the field.

## Tests

`test/tools/ota_signing_test.dart` is the contract: a key generated here, used to
sign manifest bytes, must verify under the app's real `ManifestSignatureVerifier`.
If the on-device verifier ever changes what it accepts, that test breaks before
any content is published the installed app would reject.
