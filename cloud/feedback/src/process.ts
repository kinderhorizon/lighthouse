/**
 * The relay's request -> response orchestration (ADR 0018), with NO dependency
 * on @azure/functions so it is fully unit-testable offline with a fake sender.
 * The Functions handler (functions/feedback.ts) is a thin adapter around this.
 *
 * Logging discipline (ADR 0018): the returned `log` object carries ONLY
 * {status, category?, reason?, requestId?}. The message, the email, and the
 * triage metadata are NEVER returned for logging, so App Insights cannot become
 * a second copy of vulnerable families' free text (the honeypot we refuse to build).
 */

import { buildEmail } from './email.ts';
import type { EmailSender } from './email.ts';
import { MAX_BODY_BYTES, validateFeedback } from './validate.ts';

export interface ProcessResult {
  status: number;
  /** Response body. `reason` is a stable key, never reflected user content. */
  body: { ok: boolean; reason?: string; reference?: string };
  /** The ONLY fields safe to log. No payload, no PII. */
  log: { status: number; category?: string; reason?: string; requestId?: string };
}

export async function processFeedback(
  rawBody: string,
  sender: EmailSender,
  toAddress: string,
): Promise<ProcessResult> {
  if (Buffer.byteLength(rawBody, 'utf8') > MAX_BODY_BYTES) {
    return fail(413, 'tooLarge');
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    return fail(400, 'malformed');
  }

  const result = validateFeedback(parsed);
  if (!result.ok) {
    return fail(400, result.reason);
  }
  const clean = result.value;

  try {
    await sender.send(buildEmail(clean, toAddress));
  } catch {
    // Never log the caught error: a provider error can echo the payload.
    return {
      status: 502,
      body: { ok: false, reason: 'relayFailed' },
      log: { status: 502, category: clean.category, reason: 'relayFailed' },
    };
  }

  return {
    status: 202,
    body: { ok: true, reference: clean.clientNonce },
    log: { status: 202, category: clean.category, requestId: clean.clientNonce },
  };
}

function fail(status: number, reason: string): ProcessResult {
  return { status, body: { ok: false, reason }, log: { status, reason } };
}
