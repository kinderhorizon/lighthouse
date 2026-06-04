# ADR 0018: In-app suggestion / feedback form

Status: Accepted (2026-05-31)

Graduated from TDD to ADR 2026-05-31 after reviewer sign-off. The Function code
is built and tested LOCALLY (Azurite + Functions Core Tools) with ZERO Azure
usage; deploying it + wiring the email sender are DEFERRED until the nonprofit
grant funding is confirmed. Feedback destination = `lighthouse@kinderhorizon.org`
(alias created 2026-05-31). Default impl: TypeScript Azure Function under the
lighthouse repo `cloud/` dir.

Relates to: ADR 0002 (no automatic telemetry, manual share only), the math gate
(parent-only surfaces), the on-device privacy pillar, the website GDPR posture
(`docs/compliance/`).

## The two questions, answered first

- **Is this possible?** Yes. The entry point is a math-gated parent screen
  (same gate as Settings / the board editor) with a simple form.
- **Do we need backend support?** **Yes.** A form that submits directly needs
  an endpoint to receive it. This is the case that genuinely needs compute, so
  per the stated preference it goes on **Azure**: an Azure Function (HTTP
  trigger) that validates and forwards the submission to a Kinder Horizon inbox
  (it persists NOTHING at rest, per the no-honeypot decision). (A no-backend
  `mailto:` alternative exists but is poor UX and unreliable; see Alternatives.)

## Privacy: this fits the existing model cleanly

Unlike OTA, a feedback form is **user-initiated egress**: the parent types
something and taps Send. That is the same category as "Share crash logs" and
vocab-pack sharing, both already sanctioned exceptions to "nothing leaves the
device automatically." So this does NOT require reframing the core privacy
promise; it extends the existing "you choose to send it" pattern. Requirements:

- Explicit Send action; nothing is transmitted until the parent taps it.
- A plain-language statement of exactly what is sent: the text they wrote, the
  category, an optional contact email if they choose to give one, and (proposed)
  the app version + OS version for triage. NOTHING about the child, no board
  content, no usage data, no logs.
- Add this as a third parent-initiated path in the `howWeKnowBody1` / `/privacy`
  enumeration (crash logs, vocab sharing, feedback).

## UX flow

1. Settings -> "Send feedback" (math-gated; the whole screen is parent-only).
2. Form fields:
   - **Category** (radio): Bug, Suggestion / enhancement, Other.
   - **Message** (multiline free text; required; length-capped).
   - **Contact email** (optional; "only if you want a reply").
   - Auto-attached + DISCLOSED on screen: app version, OS + version, app
     locale. (Proposed; helps triage a bug. Disclosed, not hidden.)
3. Send -> confirmation ("Thanks, this goes to the Kinder Horizon team") or a
   clear error with a retry.

## Architecture

```
App (math-gated form)
  -> HTTPS POST JSON to the Azure Function
     { category, message, contactEmail?, appVersion, osVersion, locale,
       clientNonce }   // clientNonce = per-SUBMISSION random CORRELATION id (a
                       // support ref), NOT a dedup/replay guarantee: the
                       // persist-nothing relay keeps no state to dedup against,
                       // so it is inert there. NEVER per-install (would be an
                       // identifier).

Azure Function (HTTP trigger, Consumption plan) -- ZERO-TRUST
  - re-validate EVERYTHING server-side (client validation is UX-only): required
    fields, length caps, category enum, contactEmail format, REJECT extra fields;
    body-size cap at the Function edge; treat every field as hostile, including
    appVersion/locale (they flow into the forwarded email)
  - anti-abuse: see Anti-abuse. NOTE (reviewer): real rate-limiting is at the
    EDGE (Front Door / API Management WAF rate-limit rules), NOT in Function
    memory: a Consumption plan is stateless + multi-instance + recycled, so
    in-memory per-instance counters do not limit globally, and the no-storage
    decision removes anywhere to count. In-Function limiting is best-effort at
    most. Whatever sees IPs must not log/retain them (same no-retention rule).
  - notify: forward to the KHF inbox lighthouse@kinderhorizon.org; the
    INBOX is the triage record (see Destination)
  - respond: 202 Accepted (or a structured error the app can show)
  - DO NOT LOG THE PAYLOAD (reviewer refinement #1). Azure Functions wire up
    Application Insights BY DEFAULT; logging the request body would rebuild the
    honeypot in the telemetry layer. Log only {category, status, random
    requestId}, NEVER the message body or contactEmail, to App Insights or
    Function logs. "Persist nothing at rest" must explicitly cover telemetry.
```

Resources (all consumption-based, credit-friendly; no dollar figures asserted
here, confirm against the actual Azure credit terms before committing):
- Azure Functions (Consumption) for the HTTP endpoint.
- An email sender (Azure Communication Services Email or SendGrid) for the
  forward-to-inbox.
- Shares ADR 0017's Azure resource group and the one runtime HTTP client.

Destination: **REOPENED post-review, recommend email-forward-only, no Table.**
The earlier "Table + email" call rested on a premise the reviewer correctly
demolished: that OTA "stands up an Azure backend anyway." It does NOT, OTA needs
only static Blob hosting (no Function, no DB). So a Function + Table is net-new
compute+storage that OTA never required, and a durable store of vulnerable
families' free text (names, routines, medical details, contact emails) is a PII
honeypot we would then have to secure, access-control, retain/delete per GDPR,
and answer DSARs against. **Recommendation: Function-as-relay, persist NOTHING
at rest** (validate, rate-limit, forward to the inbox, return 202); the secured
inbox is the triage record. Optional middle ground if aggregate triage is
wanted: store ONLY non-PII counters, exactly `{category, timestamp, appVersion}`,
NEVER the free text, contact email, or name, and forward the PII to the inbox
only. That set is genuinely not a honeypot and needs no DSAR machinery. **The founder to
re-decide** (this reverses the prior call on a corrected premise). If Table is
kept, retention policy + access control + RoPA entry become SHIP preconditions,
not Phase-2 risks.

**Email-forward injection (the one place user input becomes an outbound
message):** never place `message` / `contactEmail` / any user field into email
HEADERS unparsed; send the body as PLAIN TEXT (not HTML); validate
`contactEmail` strictly. This is a header/HTML-injection vector if done naively.

## Anti-abuse (the hard part, be honest about it)

The math gate is a CLIENT-SIDE child-lock, not server security; the endpoint is
public and will be hit by bots once the app is in stores. Options, weakest to
strongest:
- API key shipped in the app: trivially extractable, near useless alone.
- Server-side rate limiting (by IP) + strict payload caps + content/spam
  heuristics: cheap, stops casual abuse, not a determined attacker.
- Cloudflare Turnstile: strong for web, awkward to embed in a native Flutter
  app flow.
- **App Attest (iOS) / Play Integrity (Android)**: robust proof the request
  comes from a genuine, unmodified install. Heavier to wire up.

Recommendation: **v1 = rate-limit + payload caps + a shared key + a spam
heuristic + manual triage**, accepting some spam risk given low initial volume;
**v2 = App Attest / Play Integrity** if abuse materializes. State this trade-off
plainly rather than implying the math gate protects the endpoint.

## Offline handling

The parent may be offline. v1: fail fast with a clear "you are offline, try
later" message; the typed draft is not lost. **Known limitation, stated
plainly:** Lighthouse targets no-internet settings, so a fail-fast feedback form
simply will not work for exactly the populations we serve most. Acceptable for
v1 because feedback is non-core, but it must be acknowledged, not glossed. Phase
2 = a local queue that holds the draft (under the same privacy rules, not synced
until the parent sends) and submits when connectivity returns.

## Phasing

- **Phase 1:** math-gated form, Azure Function relay (zero-trust validation +
  rate-limit + caps), email forward to the inbox (no Table unless the founder keeps
  it), `/privacy` + in-app disclosure, fail-fast offline, RoPA/DSAR entry.
  Localized form strings (en/ar/es).
- **Phase 2:** App Attest / Play Integrity hardening; offline queue; aggregate
  triage (non-PII counters) or label routing by category if wanted.

## Open decisions (for the founder + reviewer)

1. **Destination: REOPENED, recommend email-forward-only (no Table).** The prior
   "Table + email" rested on the wrong premise that OTA stands up a backend;
   it does not (static Blob only). A durable store of vulnerable families' free
   text is a PII honeypot. Recommend persist-nothing relay; optional non-PII
   counters only. If Table is kept, retention + access control + RoPA are
   preconditions (see Risks). **The founder to re-decide.**
2. **Attestation level for v1:** rate-limit + caps (recommended, accept bounded
   spam) vs App Attest / Play Integrity up front. (Reviewer agrees v1 = rate-limit.)
3. **Auto-attach app/OS version + locale?** Recommended yes (triage value),
   disclosed on screen, with NO finer device metadata (no device model /
   identifiers; same discipline as OTA's User-Agent constraint).
4. **Attachments / screenshots?** Recommended NO for v1: a parent screenshot
   could contain the child's photos/vocabulary (privacy risk) and adds upload
   surface. Text-only keeps the data path legible.
5. **Inbox + retention (SHIP precondition, not a Phase-2 risk):** alias RESOLVED
   = `lighthouse@kinderhorizon.org` (created 2026-05-31); set a retention window,
   and document the deletion path
   in the existing `docs/compliance/` RoPA + DSAR SOP before ship.

## Testing strategy

- Form validation: required message, category enum, length cap enforced
  client-side and server-side.
- Math gate: the form is unreachable without passing the gate.
- Payload contract: the POST body matches the agreed schema (test against a
  mocked endpoint; do not hit the live Function in unit tests).
- Privacy: no child data / board content / logs are attached; only the declared
  fields are sent.
- Error + offline paths: server error and no-connectivity both show a clear,
  non-destructive message (the typed message is not lost).
- Server (separate, lightweight): validation, rate-limit, and email-forward
  behavior tested against the Function locally (Azurite + Functions Core Tools).

## Risks

- **PII honeypot if we store at rest (the headline).** A durable Table of
  parents' free text (child names, routines, medical detail, contact emails) is
  a real liability to secure, access-control, retain/delete, and DSAR against.
  The recommended email-forward-only design avoids it entirely (zero PII at
  rest; the secured inbox is the record). This risk exists ONLY if Table is
  kept, in which case retention + access control + RoPA are ship preconditions.
- **Spam / abuse** without strong attestation (covered above; v1 accepts a
  bounded risk).
- **PII in free text (even with no Table).** A parent may type a child's name,
  routine, or medical detail; it lands in the inbox. Treat every submission as
  sensitive: restricted inbox access, a retention window, plain-text email body.
- **GDPR (precondition, not a deferred risk).** A contact email + free text is
  personal data. Add the feedback channel to the existing `docs/compliance/`
  RoPA and make it DSAR-answerable (retention window, deletion path) BEFORE
  ship. Loop into the existing posture rather than inventing a new one.
- **Inbox load / triage**: define who watches the inbox and how categories
  route, before shipping, so reports are not dropped.
- **Dead UI under deploy-deferral (reviewer).** Because the endpoint does not
  exist until funded, a shipped "Send feedback" button would error on every
  tap. The surface MUST be hidden/disabled until a feedback endpoint is
  configured (gate the Settings entry on a non-empty `kFeedbackEndpointUrl`).
  Same rule applies to OTA's "Check for updates" (ADR 0017). This keeps the
  feature fully built-and-tested-locally yet invisible-until-funded.
- **`cloud/` is in a public repo (reviewer).** The TypeScript Function code is
  fine to commit, but NO connection strings / email-sender keys / secrets in
  the repo: configure them via Azure app settings / Key Vault only. The
  public-repo hygiene rule applies to `cloud/` too.

## Alternatives considered

- **`mailto:` (no backend):** opens the user's mail app with a prefilled draft.
  Zero backend, but requires a configured mail client, breaks the in-app flow,
  loses category structure, and gives no delivery guarantee. Rejected for v1 as
  poor UX, though it is the genuine zero-infra fallback if a backend is not
  wanted.
- **Reuse the crash-log share sheet:** package feedback as a shared file like
  crash logs. Works with zero backend but is clunky (the parent must pick a
  destination) and does not centralize reports. Rejected in favor of a real
  endpoint.
