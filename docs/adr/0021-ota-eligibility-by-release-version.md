# ADR 0021: OTA eligibility by release-version tag (amends ADR 0017)

Status: Accepted (2026-06-03), after reviewer sign-off. Implementation pending.

Amends: ADR 0017 (OTA content updates). Relates to: ADR 0002 (no automatic
telemetry), ADR 0008 (localization).

## The question, answered first

When an OTA content correction is later folded into the app bundle and shipped
as a new release, a fresh install of that new release should NOT be re-offered
the same correction over the air, because it already contains it. Today it is
re-offered (harmless but confusing). This ADR fixes that by tagging every OTA
manifest with the release it is destined for, and gating eligibility on the
device's own release identity. It also makes explicit the release discipline
that the gate depends on: every release bundles ALL prior corrections.

## Context: what is true today (verified in code)

ADR 0017 ships a voluntary, parent-initiated OTA channel. The relevant facts,
read from the current source:

- An OTA correction is an OVERLAY on top of the bundled asset. Publishing it
  writes files to Azure Blob only; it never touches the repo, the `assets/`
  tree, or the binary built from `main`.
- `ContentUpdateService.check()` (`lib/services/ota/content_update_service.dart`)
  decides what to offer with ONE comparison:

  ```
  manifest.sequence <= applied.sequence ? upToDate : available
  ```

  It compares the monotonic SEQUENCE NUMBER, not the actual bytes, and it has no
  knowledge of what the running binary already bundles.
- The applied sequence is persisted by the overlay store and survives an
  in-place app upgrade. A fresh install has no pointer file, so
  `OverlayState.empty()` reports `sequence = 0`
  (`lib/services/ota/content_overlay_store.dart`).
- The runtime feeds `info.version` (the marketing version) into the service
  (`lib/state/content_update_provider.dart`), e.g. `"0.1.0"`. The build number
  (`info.buildNumber`, e.g. `"7"`) is NOT passed in.
- `pubspec.yaml` is at `0.1.0+7`. Builds 5, 6, and 7 all carry the SAME
  marketing version `0.1.0`; only the `+N` build number increments per release.
- `apply()` REPLACES the active overlay file set with exactly the files in the
  manifest being applied (it does not merge). Therefore every published manifest
  must list ALL corrections that should be live (cumulative), or applying a
  newer manifest silently reverts earlier corrections. (ADR 0017 gotcha, carried
  forward here.)

### The defect this causes

Once a correction is committed into the bundle and shipped in a new release:

- A user who had ALREADY applied that OTA keeps a stored sequence equal to the
  live manifest's, so `check()` returns `upToDate`. No re-offer. Correct.
- A FRESH install of the new release, or a user who upgraded but never tapped
  "Check for updates" on the old build, has stored sequence `0`. The live
  manifest has a higher sequence, so `check()` returns `available` and offers a
  correction the binary already contains. Applying it re-downloads identical
  bytes and overlays them (same result on screen), so it is harmless, but it is
  a confusing, pointless one-time prompt.

`min_app_version` cannot fix this: it gates a manifest OUT for apps that are too
OLD (content needs a newer app). It cannot express "apps new enough to already
bundle this should skip it." That is the opposite direction.

## Decision

Two coupled parts: a release discipline, and a version-tagged eligibility gate.

### Part 1: every release bundles ALL prior OTA corrections (binding policy)

> POLICY (binding, non-negotiable): **Every new release build MUST include ALL
> previously published OTA corrections in its bundle.** A release is never
> allowed to ship "behind" the live OTA channel. The bundle catches up to the
> OTA channel at every release; it never lags it.

Why this is load-bearing, not a nicety:

- OTA corrections are an OVERLAY on the bundled asset (ADR 0017). A new install,
  or any user who never tapped "Check for updates", runs the BUNDLED asset. If a
  release ships without a correction that is live over the air, those users get
  the OLD, wrong content (e.g. the un-corrected pictogram) until and unless they
  manually check for updates.
- The ADR 0021 eligibility gate (Part 2) ASSUMES this discipline. The gate
  suppresses an OTA offer once the device's release is at or above the
  correction's `targetVersion`, on the premise that such a release already
  bundles it. If a release is tagged as bundling a correction it did not
  actually bundle, the gate will (correctly, per its contract) stop offering the
  fix, and those users silently keep the wrong content. The policy is what makes
  the gate's premise true.

The mechanics:

1. After publishing ANY OTA correction (pictogram, audio clip, board, label,
   color), ALWAYS commit the corrected asset into the repo and update its
   `sha256` in the relevant asset manifest, so the next store build bundles it.
   This is the "ALWAYS commit and push" half of the publish runbook.
2. Corrections are CUMULATIVE in the bundle: each release bundles every
   correction published before it was built, not just the newest.
3. Do NOT drop a correction from the OTA MANIFEST just because it is now bundled.
   The OTA manifest stays cumulative too (ADR 0017): an install still on an older
   binary that applies the newer manifest must receive the full set, or it
   regresses. The bundle and the manifest both carry the full history; the gate,
   not pruning, is what prevents redundant re-application.
4. Only once a release has ACTUALLY shipped containing the fold do you tag the
   manifest's `targetVersion` with that release (Part 2, HIGH-2). Never tag a
   release that has not shipped the fold.

Net invariant: at any moment, `bundled corrections (latest release)` is a
SUPERSET-or-equal of `corrections the OTA channel will hand to that release`. The
OTA channel only ever adds corrections newer than the latest release's bundle.

### Part 2: tag each manifest with a target release; gate on device release

1. The device's release identity is the combined pubspec identifier
   `"<version>+<buildNumber>"`, e.g. `"0.1.0+7"`, built from
   `info.version` and `info.buildNumber`.
2. Each OTA manifest carries a new field `targetVersion` (string, same
   `"<version>+<build>"` shape): the release that bundles this manifest's newest
   correction. It is set ONLY once that release has actually shipped the fold,
   and the manifest is re-signed at that point; it is NEVER a forward promise.
   Until the correction is folded into a shipped release, `targetVersion` stays
   null. The sequence for a correction published while build 7 is live:
   (a) publish the OTA with `targetVersion: null` (every in-field build is below
   it, so all are eligible); (b) commit the corrected asset and ship it, say in
   build 8; (c) re-build + re-sign the manifest with `targetVersion: "0.1.0+8"`
   once build 8 is live and verified to contain the fold. `targetVersion` is
   OPTIONAL; when absent (null), the manifest is always eligible (preserves
   pre-0021 behavior and keeps the field back-compatible).

   Invariant (HIGH-2): `targetVersion` MUST name a release that has actually
   shipped containing the fold. A forward reference is unsafe: if it names a
   build that then ships WITHOUT the fold (or the fold slips to a later build), a
   device on exactly that build computes `compareAppVersion == 0` (not offered)
   while its bundle lacks the fix, permanently and silently losing that
   correction for every user on that build. Raise the tag at fold-commit time,
   never before; leave it null until then (older in-field builds stay eligible,
   which is correct).
3. Eligibility becomes:

   ```
   offer  iff  manifest.sequence > applied.sequence            // not already applied
          AND  (targetVersion == null
                || compareAppVersion(deviceIdentity, targetVersion) < 0)  // bundle lacks it
   ```

4. `compareAppVersion(a, b)` splits each operand on `+`, compares the dotted
   marketing version with the existing `_compareVersions`, and breaks ties on
   the build number parsed as an integer (missing or non-numeric build -> 0).

The monotonic `sequence` is RETAINED unchanged as the anti-replay / anti-
downgrade guard (a validly signed but older manifest must never apply). The
version gate is ADDED on top to suppress redundant offers for already-bundled
content. `min_app_version` is RETAINED unchanged for genuine forward-compat.

The gate is a strict AND-narrowing on top of the security guards: it can only
ever SUPPRESS an offer, never enable an apply the sequence guard would refuse,
so it cannot weaken anti-replay. It lives ONLY in `check()`; `apply()` keeps its
sequence re-guard and gains no device-identity parameter (resolved below).

Wire invariant (HIGH-1): the version gate is evaluated entirely on-device. The
OTA wire payload is UNCHANGED by this ADR. In particular,
`HttpContentClient` keeps sending `X-Lighthouse-App-Version` equal to the
marketing version only (`0.1.0`), never the combined identity; the server never
receives the build number. This preserves the egress disclosure reconciled
field-for-field on the production privacy page and the client's own
"do not leak device model / build meta" guardrail.

### Truth table (target `0.1.0+8`, manifest sequence newer than applied)

| Device identity | compareAppVersion(device, target) | Offered? | Correct because |
|-----------------|-----------------------------------|----------|-----------------|
| `0.1.0+6`       | `< 0`                             | yes      | build 6 bundle lacks it |
| `0.1.0+7`       | `< 0`                             | yes      | build 7 bundle lacks it |
| `0.1.0+8`       | `== 0`                            | no       | build 8 bundles it (incl. fresh install) |
| `0.1.0+9`       | `> 0`                             | no       | build 9 bundles it |
| `0.2.0+1`       | `> 0` (marketing wins)            | no       | a later release bundles everything |

## Why combine version + build (not build number alone)

Build number alone works only while it increases forever. On iOS the build
number (CFBundleVersion) is permitted to RESET when the marketing version is
bumped, e.g. `0.1.0+8` followed by `0.2.0+1`. With a build-only comparison,
`+1 < +8` would WRONGLY re-offer an old correction to the newer `0.2.0+1`
release. Comparing the marketing version FIRST and using the build number only
as a tie-break is the canonical pubspec / app-store ordering and is robust to
that reset: `0.2.0+1` outranks `0.1.0+8` on the marketing segment, so it is
never re-offered. Combining is strictly more correct than either field alone,
and it reads naturally as "tagged with a release version."

## Alternatives considered

- **Compiled-in `kBundledContentSequence` floor.** A const advanced whenever a
  correction is folded into the bundle, treated as a floor on the applied
  sequence. Works, but couples the bundle to an internal OTA counter the
  publisher must hand-maintain in two places (the manifest sequence and the
  const). Rejected in favor of tagging with the release the publisher already
  knows.
- **Marketing version only.** Requires bumping `0.1.0 -> 0.1.1 -> ...` every
  release. Extra discipline with no benefit over the combined identifier, and it
  fails today because every shipped build is `0.1.0`.
- **Build number only.** Rejected for the iOS build-reset hazard above.
- **Repurpose `min_app_version`.** Wrong direction (gates old apps out, not new
  apps); also already used for true forward-compat. Rejected.
- **Per-file target tags.** More granular, but the cumulative manifest already
  makes a single manifest-level `targetVersion` (the newest correction's target)
  correct: a device below it gets the whole set in one apply, where any
  already-bundled file simply re-overlays identical bytes. Rejected as
  unnecessary complexity.

## Backward compatibility and migration

- `targetVersion` is nullable; a manifest without it behaves exactly as pre-0021
  (always eligible subject to the sequence guard). Older app builds that do not
  understand the field ignore it and keep the old behavior, which is safe (they
  pre-date the bundling of these corrections).
- The current live manifest (sequence 2, the egg + ice-cream test corrections)
  must be re-built and re-signed to add `targetVersion` once those two assets are
  bundled, set to the release that bundles them. Until then it stays null
  (always eligible), which is the present behavior.
- Signature note: `targetVersion` is part of the signed manifest bytes, so the
  manifest must be re-signed after adding it. No key change.
- Stale-cache window (LOW-2): adding `targetVersion` without bumping `sequence`
  is correct and intended, but if an edge / CDN cache serves the OLD null-tagged
  `manifest.json` + `.sig` during the swap, fresh installs of the bundling
  release keep seeing the (harmless) redundant offer until that TTL expires. That
  is cache staleness, not a gate failure. Our OTA host is direct blob with no CDN
  in front (ADR 0017), so this is largely theoretical today.

## Implementation surface

- `lib/services/ota/content_manifest.dart`: add `final String? targetVersion;`
  to `ContentManifest`; parse it; include it in equality; and in `toJson` emit
  it ONLY when non-null, mirroring the existing `if (minAppVersion != null)`
  pattern (MEDIUM-3). Always emitting `"targetVersion": null` would change the
  signed bytes of every existing null-tagged content set and break byte-identity
  / round-trip expectations.
- `lib/services/ota/content_update_service.dart`: accept the build number as a
  SEPARATE constructor parameter (`appBuild`), keeping `appVersion` untouched for
  `_isCompatible` (`min_app_version` compat). Add `compareAppVersion`, combining
  `appVersion` + `appBuild` INTERNALLY, and extend the `check()` gate per Part 2.
  `apply()` is UNCHANGED: it keeps ONLY its sequence re-guard and takes no
  device-identity parameter (MEDIUM-1).
- `lib/state/content_update_provider.dart`: pass `info.version` (as today) AND
  `info.buildNumber` as a separate field into the SERVICE only. Do NOT pass the
  combined identity into `HttpContentClient` (HIGH-1).
- `lib/services/ota/content_http_client.dart`: UNCHANGED. The
  `X-Lighthouse-App-Version` header stays marketing-version-only (`info.version`,
  `0.1.0`). The version gate is purely local; the server never receives the
  build.
- `tools/ota/build_manifest.dart`: add a `--target-version` flag, written into
  the emitted `manifest.json` (OMITTED entirely when not passed, per MEDIUM-3) so
  it is covered by the signature.
- `docs/adr/0017-ota-content-updates.md`: cross-reference this amendment.
- The OTA publish runbook (local, not committed): replace the "sequence floor,
  not yet implemented" note with this gate and the fold-time tagging step.

## Test plan (TDD)

Unit, `test/services/ota/`:

1. `compareAppVersion`: `0.1.0+7 < 0.1.0+8`; `0.1.0+8 == 0.1.0+8`;
   `0.2.0+1 > 0.1.0+8`; missing build parses as 0 (`0.1.0 == 0.1.0+0`); EMPTY
   build after `+` parses as 0 (`0.1.0+ == 0.1.0+0`, LOW-1, the case when
   `info.buildNumber` is empty on some platforms); non-numeric build parses as 0
   and does not throw. Use `int.tryParse(build) ?? 0` for the tie-break so
   empty / garbage collapses to 0 cleanly.
2. `check()` offers when `targetVersion` is null and sequence is newer
   (unchanged behavior).
3. `check()` offers when device identity is below `targetVersion` and sequence
   is newer.
4. `check()` returns `upToDate` when device identity equals or exceeds
   `targetVersion`, even though sequence is newer (the core fix; covers fresh
   install of the bundling release).
5. `check()` still returns `upToDate` when sequence is not newer, regardless of
   `targetVersion` (sequence guard intact).
6. `apply()` still refuses a non-newer sequence (anti-replay intact).
7. Wire invariant (HIGH-1): after this change, a fetch through
   `HttpContentClient` still sends `X-Lighthouse-App-Version` equal to the
   marketing version only (`0.1.0`), never the combined identity. Assert the
   outgoing header value.

Manifest round-trip, `test/services/ota/content_manifest_test.dart`: parse +
serialize with and without `targetVersion`; equality reflects the field.

## Resolved by review (2026-06-03)

1. Device identity is passed as SEPARATE `(appVersion, appBuild)` and combined
   INSIDE the service [option a]. This keeps `appVersion` untouched for
   `_isCompatible` and structurally prevents the combined identity from ever
   reaching `HttpContentClient` (reinforces HIGH-1).
2. `apply()` does NOT re-assert the version gate. Its sequence re-guard is the
   security-critical anti-replay control and stays as-is; the version gate is
   pure UX suppression and lives ONLY in `check()`. Re-asserting it in `apply()`
   would couple device identity into the security path for zero security benefit
   and could wrongly block a legitimate re-apply (e.g. after `rollback()`).
3. Boundary confirmed: `< 0` (strictly below the target is eligible; the target
   release itself is NOT). This is the intended "your bundle already has it at
   the target release" rule.
