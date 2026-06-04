# ADR 0001: Asset licensing and ARASAAC distribution strategy

**Status:** Accepted
**Date:** 2026-05-28

## Context

Lighthouse AAC needs a pictogram library. ARASAAC is the de facto international
standard (~13,000 symbols, 17+ languages, research-validated, clinician-known)
and is the right choice on product grounds. It is licensed under CC BY-NC-SA 4.0.

We want the application source code under a permissive license (MIT) so future
contributors and forks face the lowest friction. CC BY-NC-SA 4.0 and MIT have
different obligations, so we have to be explicit about how they coexist.

We also have to decide how the symbols are distributed alongside the repo.
Options considered:

- (a) Download symbols at first launch (no symbols in repo or APK)
- (b) Vendor the full ARASAAC library in-repo and ship in APK
- (c) Vendor a curated subset for MVP, manifest-driven, grow over time
- (d) Switch to a more permissive symbol set (Mulberry, Sclera, etc.)

## Decision

**Dual license by scope.** Source code under MIT (`LICENSE`). ARASAAC assets
under CC BY-NC-SA 4.0 (`LICENSES/ARASAAC.md`). The two licenses coexist because
they apply to different files, not the same files.

**Asset distribution: curated vendored subset.** Option (c). Roughly 50 symbols
for the MVP default board (Home Core 48), expandable. All committed symbols are
recorded in `assets/arasaac/manifest.json` with their ARASAAC ID, English label,
Fitzgerald category, and any build-time modifications applied. Symbols ship in
the APK so the app stays fully offline-functional.

**Attribution.** ARASAAC's required attribution wording appears verbatim in
`LICENSES/ARASAAC.md`, in `NOTICE`, and in the in-app About screen (before
public beta). Email `arasaac@aragon.es` before public beta to notify them of
this use and request inclusion in their project showcase.

**Modifications policy.** Build-time normalization (square padding, transparent
background, color tinting per Fitzgerald category) is permitted because the
entire `assets/arasaac/` bundle is one CC BY-NC-SA blob, so modified symbols
inherit the same license. Modifications applied at build time are recorded in
the manifest's `modifications` field. Runtime tinting (e.g., theme adaptation,
high-contrast mode) is not a derivative asset and does not need recording.

**Integrity policy (Phase 2).** Each symbol entry in
`assets/arasaac/manifest.json` carries an `sha256` field recording the
expected SHA-256 of the on-disk WebP. A planned `tools/verify_assets.dart`
runs as a pre-build step and fails the build on any mismatch. This detects
silent post-commit mutation (build pipeline bug, contributor accident,
supply-chain tampering). The field is reserved in the manifest schema from
day one so the schema does not need migration when the verifier lands. The
top-level `checksum_policy` block in the manifest documents the algorithm,
phase, and build-gate behavior.

## Consequences

**Foreclosed permanently (NC clause):**
- Paid white-labeling to clinics or districts
- Paid B2B licensing
- Paid certification programs ("Lighthouse-certified clinician")

Aligns cleanly with KHF's free-forever charter. If any of these paths ever become
strategically necessary, the symbol library would have to be replaced.

**Permitted under NC (per CC's actual FAQ position):**
- Transparent at-cost recovery (hosting, hardware kits sent to families at cost)

**SA clause means:** any extracted, modified, or redistributed pictogram remains
CC BY-NC-SA 4.0. Future contributors cannot strip a symbol from the bundle and
re-license it MIT. Documented in `LICENSES/ARASAAC.md`.

**Repo size stays small** because we vendor a subset, not the full library.
Growing the set is a one-command add via a planned `tools/add_symbol.dart`.

## Alternatives considered

- **(a) Download at first launch.** Rejected. Same licensing applies; the app
  ships the symbols to end users regardless. Plus a real UX regression:
  "works offline" becomes "works offline after first launch with internet."
- **(b) Vendor the full ARASAAC tree.** Rejected. Hundreds of MB of assets
  bloat every clone forever. We don't need 13,000 symbols for MVP.
- **(d) Permissive symbol set.** Rejected. Mulberry is BY-SA (still viral),
  English-heavy, and only ~3,300 symbols (gap vs ARASAAC). For an AAC product
  where having the right symbol the first time matters to a non-speaking
  child's communication success, switching for cleaner licensing is a bad trade.

## Reviewers

- Engineering review: proposed 2026-05-28
- Independent reviewer: reviewed 2026-05-28
- Independent reviewer (toolchain advisory):
  2026-05-28 with the asset-integrity sha256 verifier plan for Phase 2
- Clinical lead (BCBA): N/A (engineering decision)
