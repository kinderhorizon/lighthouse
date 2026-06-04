/**
 * Azure Communication Services email adapter (ADR 0018). The real transport
 * behind the EmailSender seam; swapped for a fake in tests.
 *
 * All configuration comes from app settings (environment variables), NEVER from
 * source. There are no secrets in this repo:
 *   ACS_CONNECTION_STRING   the ACS resource connection string (a secret;
 *                           store as a Key Vault reference in app settings)
 *   FEEDBACK_FROM_ADDRESS   the verified ACS sender (e.g. DoNotReply@<domain>)
 *
 * This file is only loaded on the deployed Function (it pulls @azure/...).
 * The pure relay logic in process.ts / validate.ts / email.ts does not, so the
 * offline tests never need this dependency or any Azure connection.
 */

import { EmailClient } from '@azure/communication-email';

import type { EmailSender, OutboundEmail } from './email.ts';

/** Ceiling on the ACS send poll so a stuck send cannot hang the invocation. */
const SEND_TIMEOUT_MS = 25_000;

/** Rejects if [promise] does not settle within [ms]. */
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`ACS send timed out after ${ms}ms`)),
      ms,
    );
    promise.then(
      (v) => {
        clearTimeout(timer);
        resolve(v);
      },
      (e) => {
        clearTimeout(timer);
        reject(e);
      },
    );
  });
}

export class AcsEmailSender implements EmailSender {
  private readonly client: EmailClient;
  private readonly from: string;

  constructor() {
    const connectionString = requireEnv('ACS_CONNECTION_STRING');
    this.from = requireEnv('FEEDBACK_FROM_ADDRESS');
    this.client = new EmailClient(connectionString);
  }

  async send(message: OutboundEmail): Promise<void> {
    const poller = await this.client.beginSend({
      senderAddress: this.from,
      content: {
        subject: message.subject,
        plainText: message.text,
      },
      recipients: { to: [{ address: message.to }] },
      replyTo: message.replyTo
        ? [{ address: message.replyTo }]
        : undefined,
    });
    // Bound the poll so a stuck send cannot hang the Function invocation (which
    // would keep the parent's Send button spinning). On timeout we throw, and
    // the relay maps it to a 502 the app shows as a retryable failure.
    const result = await withTimeout(poller.pollUntilDone(), SEND_TIMEOUT_MS);
    if (result.status !== 'Succeeded') {
      throw new Error(`ACS email send did not succeed: ${result.status}`);
    }
  }
}

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`missing required app setting: ${name}`);
  return v;
}
