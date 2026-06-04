/**
 * Builds the plain-text relay email from a validated feedback submission
 * (ADR 0018), and defines the transport-agnostic EmailSender seam.
 *
 * Plain text only (no HTML, so no markup-injection surface). Every field is
 * already control-char-stripped by validateFeedback, so nothing here can split
 * a header or terminate the body. contactEmail, if present, goes in Reply-To
 * AFTER passing the header-safe check in validate.ts. The secured inbox is the
 * record of truth; nothing is persisted by the relay (no Table, ADR 0018).
 *
 * Pure: no Azure, no I/O. Unit-tested in test/email.test.ts.
 */

import type { CleanFeedback } from './validate.ts';

/** A built, ready-to-send plain-text message. */
export interface OutboundEmail {
  to: string;
  replyTo?: string;
  subject: string;
  text: string;
}

/**
 * Transport seam. The handler depends on this, not on any provider, so the
 * relay logic is testable with a fake and the real provider (Azure
 * Communication Services) is a swappable adapter behind it.
 */
export interface EmailSender {
  send(message: OutboundEmail): Promise<void>;
}

/** Builds the email for [clean], addressed to the KHF feedback inbox [to]. */
export function buildEmail(clean: CleanFeedback, to: string): OutboundEmail {
  const subject = `[Lighthouse feedback] ${clean.category} (${clean.clientNonce})`;
  const lines = [
    `Category: ${clean.category}`,
    `App version: ${clean.appVersion}`,
    `OS: ${clean.osVersion}`,
    `Locale: ${clean.locale}`,
    `Reference: ${clean.clientNonce}`,
    clean.contactEmail
      ? `Reply to: ${clean.contactEmail}`
      : 'Reply to: (none provided)',
    '',
    'Message:',
    clean.message,
    '',
    '--',
    'Sent by the Lighthouse in-app feedback relay. No data is stored.',
  ];
  return {
    to,
    replyTo: clean.contactEmail,
    subject,
    text: lines.join('\n'),
  };
}
