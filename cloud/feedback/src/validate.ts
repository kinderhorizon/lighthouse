/**
 * Zero-trust server-side validation for an in-app feedback submission (ADR 0018).
 *
 * The app validates for UX, but this relay re-validates everything: the request
 * is untrusted. We accept ONLY the declared, low-entropy fields and bound every
 * one. Anything else (a child's name, a board, usage, a device id) is dropped on
 * the floor by construction, because we never read it.
 *
 * Pure: no Azure, no I/O, no dependencies. Unit-tested in test/validate.test.ts
 * and runnable with `node --test`, so the trust boundary is provable offline.
 */

export const FEEDBACK_CATEGORIES = ['bug', 'suggestion', 'other'] as const;
export type FeedbackCategory = (typeof FEEDBACK_CATEGORIES)[number];

/** Mirrors the client cap (lib/services/feedback/feedback_submission.dart). */
export const MESSAGE_MAX_LENGTH = 4000;
/** Triage fields are short; bound them so the email body can never blow up. */
const SHORT_FIELD_MAX = 200;
/** A whole request body larger than this is rejected before parsing. */
export const MAX_BODY_BYTES = 16 * 1024;

/** Control characters (incl. CR/LF/tab/NUL/DEL). Stripped from every field. */
const CONTROL_CHARS = /[\u0000-\u001F\u007F]/g;
/** Control characters EXCEPT tab (0x09) and newline (0x0A). Used on the message
 *  body, where newlines are legitimate (a multi-paragraph report) and cannot
 *  inject headers in a plain-text MIME body. CR (0x0D) is still stripped so
 *  line endings normalize to a bare newline. */
const CONTROL_CHARS_KEEP_NEWLINES = /[\u0000-\u0008\u000B-\u001F\u007F]/g;
/** CR/LF/tab, which would let an email header be split. */
const HEADER_BREAKERS = /[\r\n\t]/;
/** Whitespace + address punctuation that could inject a recipient or header. */
const EMAIL_UNSAFE = /[,;<>"()\[\]\\\s]/;

export interface CleanFeedback {
  category: FeedbackCategory;
  message: string;
  contactEmail?: string;
  appVersion: string;
  osVersion: string;
  locale: string;
  clientNonce: string;
}

export interface ValidationFailure {
  ok: false;
  /** A stable reason key. NEVER echoes user content (no reflection surface). */
  reason: string;
}
export interface ValidationSuccess {
  ok: true;
  value: CleanFeedback;
}
export type ValidationResult = ValidationSuccess | ValidationFailure;

/**
 * Strips ALL control characters and trims. Used on single-line / header-bound
 * fields (triage context), so a payload can never inject lines or terminators.
 */
function sanitizeText(s: string): string {
  return s.replace(CONTROL_CHARS, ' ').trim();
}

/**
 * Strips control characters but PRESERVES newlines and tabs, then trims. Used
 * on the message body only: a parent's multi-paragraph report should arrive
 * readable, and newlines cannot inject headers in a plain-text MIME body.
 */
function sanitizeMultiline(s: string): string {
  return s.replace(CONTROL_CHARS_KEEP_NEWLINES, '').trim();
}

function isString(v: unknown): v is string {
  return typeof v === 'string';
}

/**
 * Email check strict enough to use the address in a Reply-To header safely:
 * a single address, no CR/LF, no characters that could split the header or
 * inject a second recipient. Deliberately conservative (a real bounce is fine;
 * a header-injection is not).
 */
function isHeaderSafeEmail(s: string): boolean {
  if (s.length > SHORT_FIELD_MAX) return false;
  if (HEADER_BREAKERS.test(s)) return false;
  if (EMAIL_UNSAFE.test(s)) return false;
  const at = s.indexOf('@');
  if (at <= 0) return false;
  const dot = s.indexOf('.', at);
  return dot > at + 1 && dot < s.length - 1;
}

/** Validates an already-parsed JSON value. Returns clean data or a reason key. */
export function validateFeedback(body: unknown): ValidationResult {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) {
    return { ok: false, reason: 'malformed' };
  }
  const b = body as Record<string, unknown>;

  const category = b.category;
  if (
    !isString(category) ||
    !FEEDBACK_CATEGORIES.includes(category as FeedbackCategory)
  ) {
    return { ok: false, reason: 'category' };
  }

  if (!isString(b.message)) return { ok: false, reason: 'message' };
  // Bound on the raw input, before sanitizing collapses anything.
  if (b.message.length > MESSAGE_MAX_LENGTH) {
    return { ok: false, reason: 'tooLong' };
  }
  const message = sanitizeMultiline(b.message);
  if (message.length === 0) return { ok: false, reason: 'empty' };

  let contactEmail: string | undefined;
  if (
    b.contactEmail !== undefined &&
    b.contactEmail !== null &&
    b.contactEmail !== ''
  ) {
    if (!isString(b.contactEmail) || !isHeaderSafeEmail(b.contactEmail.trim())) {
      return { ok: false, reason: 'email' };
    }
    contactEmail = b.contactEmail.trim();
  }

  // Triage context: present, string, bounded. Missing -> "unknown" (the app
  // always sends them, but a relay must not assume a well-formed client).
  return {
    ok: true,
    value: {
      category: category as FeedbackCategory,
      message,
      contactEmail,
      appVersion: boundedField(b.appVersion),
      osVersion: boundedField(b.osVersion),
      locale: boundedField(b.locale),
      clientNonce: boundedField(b.clientNonce),
    },
  };
}

function boundedField(v: unknown): string {
  if (!isString(v)) return 'unknown';
  const s = sanitizeText(v);
  if (s.length === 0) return 'unknown';
  return s.length > SHORT_FIELD_MAX ? s.slice(0, SHORT_FIELD_MAX) : s;
}
