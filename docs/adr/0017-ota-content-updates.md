# ADR 0017: Over-the-air (OTA) content updates

Status: Accepted (2026-05-31). Backend DEPLOYED + live (2026-06-01).

Graduated from TDD to ADR 2026-05-31 after reviewer sign-off.

> AMENDED by ADR 0021 (2026-06-03): the offer logic gains a release-version gate
> so a correction folded into the app bundle is not re-offered over the air to a
> release that already contains it. ADR 0021 also pins the binding release
> discipline the gate depends on: EVERY new release build bundles ALL previously
> published OTA corrections (cumulative). See
> `docs/adr/0021-ota-eligibility-by-release-version.md`.

> UPDATE 2026-06-01: the Azure backend is now DEPLOYED and live. The deferral
> note below is HISTORICAL: the nonprofit grant confirmed and the stack was
> provisioned. OTA content is served from
> `https://khflighthouseota.blob.core.windows.net/content` with a signed
> `sequence 0` baseline manifest published. The canonical live resource map,
> runbook, and publishing pipeline are in `docs/azure-backend.md`. Release builds
> bake the endpoint defines via `--dart-define-from-file=config/release.json`,
> and a compile-time guard (`lib/config/release_endpoint_guard.dart`, referenced
> from `main()`) FAILS any release build that omits them, so a release can never
> ship silently dormant.

Original deferral note (HISTORICAL, superseded by the update above): All client +
tooling code is built and tested LOCALLY with ZERO Azure usage; the only
Azure-touching steps (provision Blob + CDN, deploy, budget alert) are DEFERRED
until the nonprofit grant funding is confirmed. The client targets a config base
URL that stays unset until deploy.

Relates to: ADR 0002 (no automatic telemetry), ADR 0008 (localization), ADR
0001 (asset licensing), the on-device privacy pillar.

## The two questions, answered first

- **Is this possible with our current setup?** Yes, but with a premise
  correction (reviewer, verified in code). The app does NOT today have an
  "overlay wins over bundled" pattern: `BoardRegistry`
  `tryLoad()` checks bundled `_assetSources` FIRST and only falls back to
  imported `_fileSources`; and ADR 0015 deliberately gives imports fresh,
  non-colliding ids (`imported_<n>`), so imports are SEPARATE boards, never
  overrides. OTA needs the OPPOSITE precedence (the OTA version of a given id
  must WIN over the bundled asset) and is a DIFFERENT code path from the import
  flow with OPPOSITE id semantics (OTA = same id, override; import = fresh id,
  separate). What is reusable: the `toJson`/`fromJson` serialization, the sha256
  manifest/verify discipline, and ADR 0014's `applyLayout` content-skew handling
  (built for exactly "bundled content changed under the parent overlays"). What
  is genuinely NEW: a content-overlay precedence layer across boards + audio +
  pictograms, the apply/rollback machinery, AND the first runtime outbound
  network client. Phase 1 is therefore a real build, not "one JSON file through
  the loader we already have"; re-estimate accordingly.
- **Do we need backend support?** Only **static hosting**, not a compute
  backend. OTA needs a place to serve a small versioned manifest plus content
  files, and a client that polls it. No server-side logic is required. That can
  be Azure Blob Storage + a CDN (uses the foundation's Azure credits) or the
  Cloudflare static hosting the website already runs on (zero new infra). See
  Hosting below.

## Headline decision: RESOLVED via a voluntary, user-initiated check

The privacy concern was that auto-polling a server on launch would break the
shipped claim "Lighthouse does not connect to any cloud." **Decision (the founder,
2026-05-31): the update check is voluntary and user-initiated.** The parent taps
a "Check for updates" button; the app makes a single network request only then.
The app NEVER connects on its own. This is the same model as the crash-log share
and vocab-pack sharing already shipped: nothing leaves or is fetched until the
parent chooses it.

This barely changes the privacy promise. The reframing is small and honest:
"Lighthouse never connects on its own. If you tap Check for updates, it asks the
Kinder Horizon server once whether there are content corrections, and downloads
them if so. It sends nothing about you or your child." No always-on toggle to
debate, no background polling, no launch-time call.

**Privacy-preserving constraints (to hold that promise honest):**
- The only network call happens on the explicit tap. It is an anonymous HTTPS
  GET of a small static manifest and, if the parent then applies, the changed
  content files. No cookies, no device id, no query params identifying the
  install, no request body.
- No analytics on the endpoint; minimize/disable access logging on the host so
  "who checked" is not retained.
- No push notifications. Push requires registering a device token with
  APNs/FCM, a persistent identifier and a tracking surface, and it would also
  reintroduce an unsolicited channel. The "Check for updates" tap is the only
  trigger.
- `/privacy` + `howWeKnowBody1` document the endpoint, what is and is not sent,
  and that the check is manual.

**Binding implementation guardrail (website-copy review, 2026-05-31).** "No data
leaves the tablet" stays honest ONLY if the update flow is a version query plus
a content/manifest download and NOTHING else. The request may carry, at most, an
**app-version string** (so the server can serve content a given build can
render). It must NEVER piggyback: a device ID or any stable install identifier,
usage stats, a crash/analytics rider, or install attribution. The coder must:
- send only the app-version (in the URL path or a single header), no other
  app-specific payload, no request body;
- set a minimal, non-identifying User-Agent (do not leak device model / extra
  build metadata in default headers);
- never attach anything about the child, the board, or usage.
A pedant will note the version ping is technically outbound; conventionally "no
data leaves the tablet" means *your* data, and under this guardrail that holds.
If any future change crosses this line, the claim breaks, so this is a hard
constraint, not a preference. (`minAppVersion` in the manifest lets the client
decide compatibility locally, so even the app-version string is optional, the
GET can be header-only.)

**The tradeoff this accepts (state it plainly):** because the app never checks
on its own, it cannot proactively tell a parent that a correction exists, that
would require an automatic network call. So a fix reaches a family only when
they tap Check for updates. Mitigation that stays fully offline-until-tapped: an
optional **local, no-network reminder** ("it has been a while since you checked
for updates") driven by an on-device timer, nudging the parent to check. The
reminder never touches the network; only the parent's tap does. (Open decision:
ship the reminder in v1 or not.)

## What content is OTA-able (and what is harder)

Tiered by difficulty, because the request lists "translation / vocal /
pictogram / tile color":

- **Tier A, board JSON (Phase 1).** Board `color_key` (tile colors), button
  `label`/`voice_out`, localized `label_<locale>` / `voice_out_<locale>`,
  pictogram `icon_uri` references. Reuses the `toJson`/`fromJson` serialization,
  but needs the NEW overlay-precedence resolver (an OTA board for a given id must
  win over the bundled asset; see the premise correction above). A "wrong tile
  color", "wrong label translation", or "wrong word" is fixed here, SUBJECT to
  the hard constraints below (no id changes, no repositioning).
- **Tier B, audio clips (medium, Phase 1).** The pre-rendered neural MP3s
  (`assets/audio/...`, filename = sha256(text)). A "wrong vocal" is a replaced
  clip file. The manifest already carries content sha256, so integrity checking
  is the existing pattern.
- **Tier C, pictogram images (Phase 1).** ARASAAC PNGs; a new overlay resolver
  (image: overlay first, else bundled). ARASAAC is **CC BY-NC-SA**, so
  redistributing corrected pictograms from the KHF CDN carries three
  obligations, with a nuance (reviewer):
  - **Non-commercial (NC):** judged by the USE, not the entity. Being a
    nonprofit does not by itself make a use non-commercial; what matters is that
    THIS use (free distribution inside a free, ad-free, donation-funded AAC app)
    is non-commercial. Do not rest the reasoning on "we are a nonprofit".
  - **Attribution (BY):** the **publish pipeline must ENFORCE** attribution
    travels with OTA'd images (ADR 0001), not a manual "confirm".
  - **Share-alike (SA):** scope a "pictogram correction" to **SWAPPING to a
    different existing ARASAAC asset**, not creating a derivative (editing the
    image). A swap carries no new SA obligation; an edited derivative would have
    to be released under the same license. If we ever ship edited pictograms,
    handle SA explicitly.
- **Tier D, app-chrome UI strings (hard, Phase 2).** The `.arb` strings are
  compiled into Dart by `gen_l10n`, so they cannot be swapped at runtime
  without a new layer: a runtime override map (downloaded JSON of
  `key -> string` per locale) consulted before the compiled `AppLocalizations`.
  Most "wrong translation" complaints for an AAC app are about the VOCABULARY
  (Tier A board labels/voice_out), which Phase 1 already covers; app-chrome
  strings are fewer and lower-stakes, so they are deferred to Phase 2.

## Hard content-authoring constraints (ADR 0009 + ADR 0006, binding)

An OTA fix changes a non-speaking child's only voice, so what a content update
may change is tightly bounded:

1. **Preserve identity. (ADR 0009.)** An OTA update MUST keep the `board_id` and
   every `buttonId` and `category` stable. Bandit posteriors, favourites pins
   (ADR 0013), and layout overrides (ADR 0014) are ALL keyed on `buttonId`, and
   `category` drives the semantic glow boost (ADR 0011) + color fallback. A fix
   that renames or re-ids a button silently orphans all of that. The **publish
   pipeline asserts id-stability against the prior manifest**: a diff that
   changes/removes a `buttonId` (or `category`) is rejected or flagged as a
   breaking change requiring explicit sign-off.
2. **Do not move the child's tiles. (ADR 0006/0009 motor memory.)** An OTA update
   may change PRESENTATION (label text, translation, color, pictogram, audio)
   but MUST NOT change an existing button's `position`, nor remove/relocate
   existing buttons so the grid reshuffles. Adding a button to a previously
   EMPTY slot is allowed (it does not move existing tiles); relocating or
   removing an existing one is not.
3. **Apply at a child-safe time, not mid-session.** "Atomic apply" guarantees
   consistency, not timing. Even a color/pictogram swap is visible to the child,
   so an applied update takes effect at next launch (or a parent-gated apply
   moment), never while the child is mid-session. The parent should see what
   changed (motor-planning courtesy).

   > Amendment (build 7): "next launch" no longer means the parent must manually
   > kill and reopen the app (confusing, and impossible to automate on iOS, which
   > forbids self-relaunch). Apply happens only in Settings, which is itself a
   > parent-gated, child-safe moment, so the success card now offers a
   > "Show the update now" button that performs an in-app soft restart
   > (`RestartWidget`, a root re-mount, not an OS process restart) to re-read the
   > corrected content immediately. The deferred-to-next-launch path remains as
   > the fallback for a parent who just backs out without tapping it.

## Architecture

```
Azure Blob Storage + CDN (static host)
  /content/manifest.json          <- versioned index, per-file sha256, SIGNED
  /content/boards/<id>.json
  /content/audio/<sha>.mp3
  /content/pictograms/<name>.png

App
  ContentUpdateService
    - ONLY on the parent's "Check for updates" tap (math-gated): GET manifest.json
    - VERIFY the manifest SIGNATURE against the bundled public key (v1), then
      diff manifest.version + per-file sha256 vs the local overlay state
    - if newer: show what is available; on the parent's "Apply", download only
      changed files to a temp dir, verify each sha256, then ATOMICALLY swap into
      the content-overlay dir (applied at next launch, not mid-session); record version
    - if nothing new: "You are up to date." No background work, ever.
    - never deletes the bundled assets; overlay is purely additive precedence
  Content resolution (NEW overlay-precedence layer)
    - This is a NEW resolver and the OPPOSITE of today's import precedence
      (BoardRegistry checks bundled FIRST). It is also a different path from ADR
      0015 import (which mints a fresh id, separate board). Here: same id, OTA
      version WINS over the bundled asset.
    - boards: OTA-overlay <id>.json wins, else bundled asset
    - audio: OTA-overlay clip wins, else bundled asset
    - pictograms: OTA-overlay image wins, else bundled asset
  Result UI (no push, no launch badge)
    - the "Check for updates" screen shows the outcome of the tap: up to date,
      or N corrections available -> Apply (or auto-apply on the same tap; open
      decision below). Optional local no-network reminder to check periodically.
```

**Manifest shape (sketch):**
```json
{
  "schemaVersion": 1,
  "contentVersion": "2026-05-31T12:00:00Z",
  "minAppVersion": "1.0.0",
  "files": [
    { "path": "boards/board_body.json", "sha256": "...", "bytes": 1234 },
    { "path": "audio/<sha>.mp3", "sha256": "...", "bytes": 5678 }
  ]
}
```
`minAppVersion` lets the server avoid pushing content a given app build cannot
render (e.g. a board JSON using a schema field that build does not know).

**Integrity + safety (non-negotiable for an AAC app that a child relies on):**
- Verify every downloaded file's sha256 against the manifest before applying;
  a mismatch aborts that file (keep the prior version).
- Atomic apply: download to temp, verify the whole set, then swap; never a
  half-applied board.
- Fallback: if an applied board later fails to parse at load time, fall back to
  the bundled asset and log it. The grid for a non-speaking child never breaks.
  (Same principle as `BoardLoader`'s no-silent-failure rule.)
- Keep last-known-good so a bad content version can be rolled back on-device.

## Hosting: Azure Blob Storage + Azure CDN (decided)

**Decision (the founder, 2026-05-31): Azure.** OTA needs static hosting only:
**Azure Blob Storage** (a public-read container for the manifest + content
files) behind **Azure CDN / Front Door**. Funded by the foundation's annual
Azure credits and consolidated with the ADR 0018 feedback backend on one stack.

Cloudflare was considered (it already hosts the website) and rejected for this:
the foundation's Cloudflare account is on the FREE tier, and OTA content
downloads plus a feedback endpoint could push it past free limits and force a
paid upgrade. Spending Azure credits we already have beats upgrading Cloudflare.
The client code is hosting-agnostic regardless (it just points at a base URL).

**Publishing pipeline:** a build-time tool (mirroring the existing
`tools/verify_assets.dart` / `generate_clips.dart` style) that takes the
corrected content, computes sha256s, writes `manifest.json`, and uploads to the
host. Content changes become a publish step, not an app release.

## App-store policy (must state explicitly)

Apple and Google permit OTA updates of **data/content** (JSON, images, audio)
but PROHIBIT downloading **executable code** that changes app behavior. This
design ships only data, so it is compliant. We must never use this channel to
deliver code or logic, only content files, and should say so in the TDD/ADR so
it is never bent later.

## Phasing

- **Phase 1:** Tiers A+B+C (board JSON, audio, pictograms), a math-gated
  "Check for updates" action (voluntary, on-demand), result UI, integrity +
  atomic apply + fallback, the small `/privacy` + `howWeKnowBody1` wording
  update, optional local reminder. Static host on Azure (or CF).
- **Phase 2:** Tier D (runtime app-chrome string overrides). (NOT "staged
  rollout controls": that needs real client-cohort design and, under the
  voluntary-check model, still cannot recall content from devices that already
  applied it, see Decision 2.)
- **Phase 3:** per-locale or per-region content channels if ever needed.

## Open decisions (mostly resolved post-review)

1. **Privacy model: RESOLVED.** Voluntary, user-initiated "Check for updates"
   tap; no auto-poll, no push, no background call (see Headline decision).
   On-demand only; no always-on toggle to default.
2. **Auto-apply vs review-and-apply: RESOLVED, review-and-apply** (reviewer).
   Show "here is what changed, Apply?"; apply at a child-safe time (next launch,
   not mid-session); the parent sees what changed (motor planning).
   **Correction (reviewer):** there is NO classical "staged rollout / kill
   switch" under this design. Because the app never phones home on its own, a
   device that already applied bad content keeps it until the parent taps Check
   again; republishing a good manifest only helps devices that have not checked
   yet (and the monotonic guard means the fix must be a HIGHER sequence, not a
   re-publish of the old one). So the real safeguards are: the pre-publish
   id-stability / no-reposition asserts, manifest signing, the downgrade
   (monotonic) guard, the review-and-apply human gate, and on-device
   last-known-good fallback. Do not claim proactive recall we cannot deliver.
3. **Local reminder in v1: RESOLVED, yes** (reviewer). On-device timer, no
   network; it is the mitigation for the voluntary-check tradeoff (a wrong word
   on a child's only voice must not go uncorrectable forever).
4. **Manifest signing: RESOLVED, v1, as a TRUST-LIST** (reviewer; I agree).
   sha256-in-manifest proves a file matches the manifest, NOT that the manifest
   is authentic; a compromised blob/CDN or MITM could serve a
   malicious-but-consistent manifest, and this channel changes a non-speaking
   child's only voice. Verify a manifest signature in v1. HTTPS is necessary,
   not sufficient; sign the content rather than pin the transport (public blob +
   CDN makes cert pinning fragile). **Rotation mechanism (reviewer refinement
   #3):** bundle a small **trust-list of public keys (current + next)** the app
   will accept, NOT a single key, so key rotation is not a breaking,
   app-update-coupled cutover. The **private key is used only in the publish
   pipeline** (a `verify_assets`-style signing tool), NEVER in Azure and NEVER
   in the app. This is the mechanism that makes the custody/rotation cost
   manageable. **Canonical bytes (reviewer):** the signature is computed and
   verified over the EXACT `manifest.json` byte stream (detached `.sig`), and
   the manifest is parsed from those same bytes, never a re-serialized object,
   so JSON key-ordering / whitespace can never break verification. (The
   implementation does exactly this.)
5. **Downgrade/rollback-attack protection: RESOLVED, wired** (reviewer). A
   validly-signed OLD manifest (replayed stale cache / attacker) must not roll a
   device back; signature checks alone would not catch it. The manifest carries
   a monotonic `sequence`, the overlay store persists the applied sequence, and
   the update service refuses (check + apply) any manifest whose sequence is
   <= the applied one.
5. **Host: RESOLVED, Azure Blob + CDN** with a HARD no-IP-retention
   requirement. **Two separate toggles (reviewer refinement #2):** disable BOTH
   Storage analytics logging AND Front Door / CDN access logs, they are
   different settings, and the IP trail survives in whichever one is forgotten.
   The fact + timing of a connection to a KHF endpoint is itself the sensitive
   signal for vulnerable populations; state it in `/privacy` and enforce both
   toggles in the infra setup. Cloudflare rejected to avoid a paid upgrade of
   the free CF account.
6. **Runtime network client: RESOLVED, new shared component.** The app ships no
   runtime HTTP client today (`http` is dev-only). OTA adds the first; make it
   HTTPS-only (reject cleartext), restricted to the KHF endpoint set, and shared
   with ADR 0018 as one reviewed component.

## Testing strategy

- Overlay precedence: a board/clip/pictogram in the overlay dir wins over the
  bundled asset; absent overlay falls back to bundled.
- Integrity: a file whose bytes do not match the manifest sha256 is rejected
  and the prior version is kept.
- Atomic apply: an interrupted/partial download never leaves a half-applied
  board; last-known-good is restored.
- Offline: with no network (or the toggle off) the app behaves exactly as
  today, fully offline, no errors.
- Manifest robustness: malformed/empty manifest is a no-op, never a crash.
- Privacy: the check sends no identifying headers/params/body (assert the
  request shape).
- `minAppVersion`: content requiring a newer app is not applied.

## Risks

- **Privacy posture** (the headline, now largely defused). The voluntary
  user-initiated check means the app never phones home on its own, so this drops
  from a posture change to a small honest wording update. Residual: the network
  GET still exposes the install's IP + timing to the host at check time;
  mitigated by no endpoint analytics / minimized logging.
- **A bad push reaches checking devices, with NO proactive recall.** OTA's
  speed cuts both ways, and the voluntary-check design means there is no kill
  switch: a device that already applied bad content keeps it until the parent
  taps Check again. Honest mitigations (NOT staged rollout / recall, which this
  design cannot do): the pre-publish id-stability + no-reposition asserts,
  manifest signing, the downgrade (monotonic-sequence) guard, the
  review-and-apply human gate, and on-device last-known-good fallback. The real
  defense is getting the published manifest right before publishing, since you
  cannot pull it back from devices that already took it.
- **Licensing** of re-distributed ARASAAC pictograms via our CDN (ADR 0001);
  confirm attribution requirements travel with OTA'd images.
- **Scope creep into Tier D**; keep app-chrome string OTA explicitly Phase 2.
