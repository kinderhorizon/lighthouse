# Lighthouse feedback relay (ADR 0018)

A zero-trust, **stateless** HTTP relay: it takes a validated in-app feedback
submission and forwards it to the KHF feedback inbox (whatever
`FEEDBACK_TO_ADDRESS` is set to at deploy time) as a plain-text email.
**Nothing is stored** (no Table, no database): a durable store of vulnerable
families' free text would be a PII honeypot. The secured inbox is the record.

> **`FEEDBACK_TO_ADDRESS` must be a verified, non-suppressed mailbox.** Do not
> reuse an address that has previously bounced or been suppressed by Azure
> Communication Services: ACS still returns 202 for a suppressed recipient, so
> the relay reports success while the mail is silently black-holed (and every
> send extends the suppression lease). Confirm the live inbox before setting it.

Azure Functions v4 (Node, TypeScript, ESM).

## Privacy and security posture

- **Zero-trust validation** (`src/validate.ts`): the relay re-validates the
  request and accepts ONLY the declared low-entropy fields (category, message,
  optional contact email, app/OS version, locale, a per-submission nonce).
  Anything else in the payload is dropped by construction.
- **No payload in telemetry** (`src/process.ts`): the only thing logged is
  `{status, category?, reason?, requestId?}`. The message, the email, the
  metadata, and any provider error are never logged, so Application Insights
  cannot become a second copy of the inbox. `host.json` also excludes Request
  and Exception telemetry types from sampling.
- **Plain-text email, injection-safe** (`src/email.ts`): the body is plain text
  (no HTML), every field is control-char-stripped, and a contact email is only
  used in `Reply-To` after passing a strict header-safe check (no CR/LF, no
  characters that could split the header or inject a recipient).
- **No secrets in the repo**: all configuration is read from app settings
  (`ACS_CONNECTION_STRING`, `FEEDBACK_FROM_ADDRESS`, `FEEDBACK_TO_ADDRESS`).
  Store the connection string as a Key Vault reference. `local.settings.json` is
  gitignored; copy `local.settings.json.example` and fill it in locally.
- **Rate limiting is at the EDGE**, not here. A stateless Function scaled across
  instances cannot keep a shared counter, so an in-memory limiter would be
  per-instance and trivially bypassed. Enforce limits with Azure Front Door /
  API Management in front of the Function. The only Function-local guard is the
  16 KB body-size cap (cheap DoS hygiene).

## Layout

```
src/validate.ts        zero-trust validation (pure, no deps)
src/email.ts           plain-text email builder + EmailSender seam (pure)
src/process.ts         request->response orchestration (pure, no @azure deps)
src/acsEmailSender.ts  Azure Communication Services adapter (deploy only)
src/functions/feedback.ts  thin Functions v4 HTTP handler
test/*.test.ts         offline unit tests (node --test, no install needed)
```

The pure modules carry all the logic and the trust boundary, so they are tested
with **zero dependencies and zero Azure** via Node's built-in runner.

## Develop and test (no Azure)

```
# Logic tests run with no install at all (Node 22+ strips TS types):
node --test test/*.test.ts

# Type-check / build the full source (needs the npm deps, public registry only):
npm install
npm run typecheck
npm run build        # emits dist/ (ESM; .ts import specifiers rewritten to .js)
```

To run the whole Function host locally you also need the Azure Functions Core
Tools (`func`) and a `local.settings.json` (from the example). `npm start` runs
`func start`. This is still local; no Azure resource is touched.

## Deploy (DEFERRED, Azure-touching)

Do **not** deploy until the Microsoft for Nonprofits Azure grant balance is
confirmed (see the `lighthouse-backend-azure` running note). Deploy is the hard
stop. When the grant is live, the order is:

1. Provision a resource group, an Azure Communication Services Email resource
   (verified sender domain), and a Function App (Consumption plan).
2. Set app settings: `ACS_CONNECTION_STRING` (Key Vault reference),
   `FEEDBACK_FROM_ADDRESS`, `FEEDBACK_TO_ADDRESS`.
3. `npm run build` then `func azure functionapp publish <app-name>`.
4. **HARD GATE before step 5:** put Front Door / API Management in front with a
   rate-limit rule, block direct Function-URL access, and run a throttling
   smoke-test (hammer the edge URL, confirm it 429s after the threshold). The
   endpoint is `authLevel: 'anonymous'` by design and the Function cannot
   rate-limit itself (stateless, multi-instance). Until the edge limit is live
   and verified, setting `kFeedbackEndpointUrl` would ship an open,
   unauthenticated email relay into the KHF inbox: a spam/abuse amplifier.
5. ONLY after step 4 passes: set `kFeedbackEndpointUrl` in a shipped app build
   to the EDGE URL (never the raw Function URL) so the in-app feedback entry
   appears (it is dead-UI-gated until then).
6. Add a Cost Management budget + alert.
