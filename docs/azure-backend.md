# Azure backend: architecture, runbook, and incident lessons

Reference for the Lighthouse cloud backend (OTA content updates, ADR 0017; and
the in-app feedback relay, ADR 0018). This is the **sanitized, version-controlled**
copy: subscription ID, Front Door ID, Key Vault + secret names, and resource names
appear as `<PLACEHOLDERS>`. The real values live in 1Password and in the local-only
working copy `docs/azure-deploy-state.md` (gitignored). The two service URLs below
are NOT redacted because they are already baked into the open-source app builds and
are therefore public regardless.

All resources are in one resource group, region `canadacentral` (Canadian data
residency), under the KHF Microsoft-for-Nonprofits sponsorship subscription.

## Public endpoints (baked into app builds, not secret)

- **OTA_BASE_URL** = `https://khflighthouseota.blob.core.windows.net/content`
- **FEEDBACK_URL** = `https://<fd-endpoint-host>.z03.azurefd.net/api/feedback`
- **PRIVACY_POLICY_URL** = `https://kinderhorizon.org/lighthouse/privacy`

The OTA host is a fixed blob hostname; the feedback host is an Azure Front Door
endpoint hostname (random suffix). All three are shipped via `--dart-define` and
are visible in the public repo and the published binaries.

### Building a release with the endpoints baked in (required)

The three defines (`OTA_BASE_URL`, `FEEDBACK_URL`, `PRIVACY_POLICY_URL`) default
to empty (`String.fromEnvironment` in `lib/services/ota/ota_config.dart`,
`lib/services/feedback/feedback_config.dart`, `lib/services/legal/legal_config.dart`),
and each feature dead-UI-gates itself OFF when its define is empty. So a release
that forgets them ships SILENTLY DORMANT (no OTA, no feedback, no privacy link)
and cannot be fixed without a new app-store submission.

The committed values live in `config/release.json`. Build every store release
with that file:

```
flutter build ipa --release --dart-define-from-file=config/release.json
flutter build appbundle --release --dart-define-from-file=config/release.json
```

A compile-time guard, `lib/config/release_endpoint_guard.dart` (referenced from
`main()`), uses a const-constructor assert to FAIL the release build at compile
time if any of the three is empty, so the silent-dormant footgun is impossible.
The guard only fires on product-mode targets (`ipa` / `appbundle` / `apk`
`--release`), which are the store artifacts; debug and profile builds are
unaffected. For a deliberately-dormant LOCAL release build (a perf or size smoke
test before the endpoints matter), pass
`--dart-define=ALLOW_UNCONFIGURED_RELEASE=true`.

## Architecture

| Purpose | Resource | Notes |
|---|---|---|
| Cost guardrail | budget `<BUDGET_NAME>` | 150 CAD/mo, alerts at 50/80/100% actual + 100% forecast -> founder email |
| Volume backstop | alert `<VOLUME_ALERT>` | ACS ApiRequests count > 100/1h (catches an email-bomb before the monthly budget) |
| Bounce monitor | alert `<BOUNCE_ALERT>` | ACS DeliveryStatusUpdate, MessageStatus includes Bounced > 0/1h (early warning before silent suppression) |
| OTA host | storage account + container `content` | public read at blob level (no listing), HTTPS-only, TLS1.2, no logging |
| OTA signing | offline Ed25519 key (perms 0600, NOT cloud-synced) + 1Password | public key in the app's `kOtaTrustedPublicKeys` (a `List<String>` -> multi-key rotation supported); baseline `sequence 0` manifest published |
| Feedback compute | Function app `<FUNCTION_APP>` (Flex Consumption, Node 22) | ADR 0018 relay, route `POST /api/feedback`, authLevel anonymous |
| Email | ACS resource `<ACS_RESOURCE>` + custom domain `mail.kinderhorizon.org` (SPF/DKIM/DKIM2/DMARC verified; `mail.` subdomain only, apex Workspace MX/SPF untouched) | sender `donotreply@mail.kinderhorizon.org` -> internal feedback inbox |
| Secret | Key Vault `<KV_NAME>`, secret `<SECRET_NAME>` | RBAC, soft-delete + purge protection on; Function managed identity = Key Vault Secrets User |
| Edge / WAF | Front Door Standard `<FRONTDOOR_PROFILE>`, endpoint `<FD_ENDPOINT>` | WAF `<WAF_POLICY>` (Prevention), rate limit 10 POST/min/IP -> Block |

Identifiers kept out of this file (see 1Password / `docs/azure-deploy-state.md`):
subscription ID, resource group name, Front Door ID (`x-azure-fdid`), and the
concrete resource names above.

### Origin lock

The Function is locked to ONLY this Front Door profile: an access restriction
`allow-frontdoor` requires BOTH the service tag `AzureFrontDoor.Backend` AND the
header `x-azure-fdid` = this profile's Front Door ID (ANDed), with implicit Deny
all. The SCM site inherits the lock (`scmIpSecurityRestrictionsUseMain = true`).
A direct public POST to the Function origin returns 403.

The FDID is not a credential and cannot be spoofed through an attacker's own
Front Door (Front Door sets `X-Azure-FDID` to the real profile ID server-side),
so the lock does not depend on the FDID staying secret. It is kept out of this
public doc as defense-in-depth with zero upside to publishing.

## Security posture (verified)

- FDID + service-tag lock enforced; public direct POST = 403; SCM inherits the lock.
- WAF Prevention + Block, **rate limit enforcing** on the default `.azurefd.net`
  domain. Verified by 40 POSTs over ONE keep-alive connection -> a wall of 429
  "The request is blocked". (Per-request curl testing gives false negatives: each
  new TCP connection can land on a different edge server with its own counter;
  Microsoft documents this for thresholds below ~200/min.)
- No payload logging. The relay logs only `{status, category?, reason?, requestId?}`,
  never the message, email, or metadata. No diagnostic settings on Front Door,
  blob, or Function; classic Storage Analytics off. Privacy holds at the platform
  layer.
- Email: custom domain fully verified (SPF/DKIM/DKIM2/DMARC); relay sends from
  `donotreply@mail.kinderhorizon.org`; delivery to the internal inbox confirmed
  end-to-end.
- Reply-To set to the parent's contact email when present, graceful (and
  header-injection-safe) when absent.
- Storage HTTPS-only, container access "blob" (no enumeration), TLS1.2.
- Key Vault RBAC + Secrets User least privilege + soft-delete + purge protection;
  the ACS connection string is a `@Microsoft.KeyVault(...)` reference, never inline.
- CORS empty (native app, no browser origin).
- The relay has **no default recipient**: if `FEEDBACK_TO_ADDRESS` is missing or
  blank it returns 500 `misconfigured` rather than falling back to a hardcoded
  inbox (see `cloud/feedback/src/functions/feedback.ts`). A stale or dropped
  setting fails loudly instead of silently routing real feedback to a guessed,
  possibly-dead address.
- OTA baseline `sequence 0`: `0 <= applied 0` -> upToDate (no apply); empty file
  list (no-op even if applied); the baseline manifest is signed (fail-closed).
- Submit idempotency: the app disables the Send button while a submit is in flight
  (`feedback_screen.dart`); Front Door origin timeout 30s > Flex cold start (~10s);
  per-submission client nonce. Duplicate-on-retry risk is low.

### Residual / optional hardening (none blocking)

- `authLevel: function` belt-and-suspenders. The FDID + service-tag lock keeps the
  relay non-public today; a function key would also survive an FDID-rule regression
  in a future deploy.
- Key Vault public network access still Enabled (secret is RBAC-protected).
  Restricting it risks breaking the Flex KV reference; revisit with a private
  endpoint if desired.
- Tell staff the feedback sender is `donotreply@mail.kinderhorizon.org` and add an
  inbox rule so real feedback is not dismissed as automated mail.
- The feedback recipient is a single critical inbox. Mitigation: the bounce alert
  flags a bounce immediately. If that inbox ever auto-suppresses, it is the same
  managed-platform list described below: never test-send to a recipient before
  confirming the alias exists, and on a bounce alert STOP sending.

## OTA recovery + key runbook

**Content correction / rollback**

- Publish a NEW manifest with `sequence` = previous + 1 (strictly increasing),
  signed with the offline key, plus the corrected files; upload `manifest.json`,
  `manifest.json.sig`, and the files to the `content` container.
- To recover from a bad manifest N: publish N+1. NEVER unpublish or rewrite N.
  Clients that applied N (or rolled back to N-1) only move on via a strictly-higher
  sequence.
- The Ed25519 signature is the integrity anchor; TLS and Front Door are
  transport/abuse layers, not the integrity guarantee.

**Signing-key compromise / rotation** (no in-channel revocation, plan ahead)

- A leaked key stays trusted until an app-store update drops it from
  `kOtaTrustedPublicKeys` AND devices update; the OTA channel cannot revoke itself
  (the attacker holds the same key).
- `kOtaTrustedPublicKeys` is a `List` -> non-breaking rotation: generate key B,
  ship an app trusting `[A, B]`, start signing new content with B, then drop A in a
  later build once enough installs trust B.
- On compromise: generate B, ship `[A, B]` (or `[B]` if you accept a flag-day),
  re-sign current content with B, bump `sequence`, and treat A as burned.
- Key hygiene: the signing seed is `0600`, outside any cloud-synced folder, and
  mirrored in 1Password. Prefer pulling it from 1Password per-sign over leaving it
  resident on disk.

## Incident lessons (keep, do not relearn the hard way)

**ACS managed-suppression hard bounce.** Test-sending to an address that does not
yet exist produces a hard bounce, which lands the address on the ACS
managed-platform suppression list. That list is NOT customer-API-removable; it
clears only via Microsoft support or expiry (escalating lease up to ~14 days), and
**every further send to a suppressed address re-extends the lease**. The first
feedback inbox was burned this way and had to be abandoned for a fresh alias.
Rules that fell out of it:

1. Never test-send to a recipient before confirming the alias exists and receives.
2. On a bounce/suppression alert, STOP sending immediately. Do not "retry to see."
3. The customer/domain-level suppression list (separate from the managed one) IS
   API-manageable, but it does not help with managed-platform suppression.

**WAF rate-limit test methodology.** Front Door per-IP rate limiting counts
per-edge-server and is approximate. Spraying N separate `curl` invocations opens N
TCP connections that scatter across edge servers, so the counter never trips and
the limiter looks broken. Correct test: many requests over ONE keep-alive
connection. Microsoft documents this caveat for thresholds below ~200/min.

**Verify before asserting.** Do not state third-party behavior, limits, or
timelines as fact without checking the authoritative doc first; if unverified, say
so up front. A confident guess that flips under scrutiny is worse than admitting
uncertainty at the start.

## History note

The Front Door edge rollout initially showed `deploymentStatus: NotStarted` and
404s, then resolved on its own once changes stopped. That status field is
cosmetic/unreliable on this profile: the route and WAF both work despite it. No
custom domain was needed for the WAF; the default `.azurefd.net` domain enforces it.
