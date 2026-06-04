/**
 * HTTP-triggered feedback relay (ADR 0018), Azure Functions v4 model.
 *
 * Thin adapter: it reads the raw body, hands it to the pure processFeedback
 * orchestration with the real ACS sender, maps the result to an HTTP response,
 * and logs ONLY the non-PII {status, category?, reason?, requestId?}. All real
 * logic and the trust boundary live in ../process.ts (offline-tested).
 *
 * Anti-abuse: rate limiting is enforced at the EDGE (Azure Front Door / API
 * Management), NOT here. A stateless Function scaled across instances cannot
 * keep a shared counter, so an in-memory limiter would be per-instance and
 * trivially bypassed. The only Function-local guard is the body-size cap in
 * processFeedback (cheap DoS hygiene, not a rate limit). See README.
 */

import { app } from '@azure/functions';
import type { HttpRequest, HttpResponseInit, InvocationContext } from '@azure/functions';

import { AcsEmailSender } from '../acsEmailSender.ts';
import type { EmailSender } from '../email.ts';
import { processFeedback } from '../process.ts';
import { MAX_BODY_BYTES } from '../validate.ts';

// Lazily constructed so a missing app setting fails the first request (logged),
// not module load, and so tests never trigger it.
let sender: EmailSender | undefined;
function getSender(): EmailSender {
  sender ??= new AcsEmailSender();
  return sender;
}

// No default recipient. A relay that silently falls back to a hardcoded inbox
// is a footgun: a stale or dropped FEEDBACK_TO_ADDRESS would route real parents'
// feedback to a guessed (and possibly dead) address. Missing config must FAIL
// loudly, never send to a default.
function toAddress(): string | undefined {
  const to = process.env.FEEDBACK_TO_ADDRESS;
  return to !== undefined && to.trim().length > 0 ? to : undefined;
}

export async function feedbackHandler(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  // Reject by declared Content-Length BEFORE buffering the body. The real
  // ingress DoS guard is the edge (Front Door / APIM); this just avoids reading
  // a large body into the Function when the client announces one. processFeedback
  // re-checks the actual byte length as a backstop (a client can lie or omit it).
  const declaredLength = Number(request.headers.get('content-length') ?? '0');
  if (Number.isFinite(declaredLength) && declaredLength > MAX_BODY_BYTES) {
    context.log('feedback', { status: 413, reason: 'tooLarge' });
    return {
      status: 413,
      jsonBody: { ok: false, reason: 'tooLarge' },
      headers: { 'Content-Type': 'application/json' },
    };
  }

  const recipient = toAddress();
  if (recipient === undefined) {
    // Refuse to send rather than fall back to a hardcoded recipient. A visible
    // 500 surfaces the misconfig instead of silently delivering to a dead inbox.
    context.log('feedback', { status: 500, reason: 'misconfigured' });
    return {
      status: 500,
      jsonBody: { ok: false, reason: 'misconfigured' },
      headers: { 'Content-Type': 'application/json' },
    };
  }

  const rawBody = await request.text();
  const result = await processFeedback(rawBody, getSender(), recipient);
  // Non-PII log line only (ADR 0018): never the message, email, or metadata.
  context.log('feedback', result.log);
  return {
    status: result.status,
    jsonBody: result.body,
    headers: { 'Content-Type': 'application/json' },
  };
}

app.http('feedback', {
  methods: ['POST'],
  authLevel: 'anonymous',
  handler: feedbackHandler,
});
