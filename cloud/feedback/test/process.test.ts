import { test } from 'node:test';
import assert from 'node:assert/strict';

import { processFeedback } from '../src/process.ts';
import type { EmailSender, OutboundEmail } from '../src/email.ts';

const TO = 'lighthouse@kinderhorizon.org';

class FakeSender implements EmailSender {
  sent: OutboundEmail[] = [];
  shouldThrow = false;
  async send(message: OutboundEmail): Promise<void> {
    if (this.shouldThrow) throw new Error('provider down (must not be logged)');
    this.sent.push(message);
  }
}

function payload(over: Record<string, unknown> = {}): string {
  return JSON.stringify({
    category: 'bug',
    message: 'It crashed on the food board',
    appVersion: '1.0.0',
    osVersion: 'ios 18.0',
    locale: 'en',
    clientNonce: 'ref-123',
    ...over,
  });
}

test('valid submission: 202, email sent once, log carries no payload', async () => {
  const sender = new FakeSender();
  const r = await processFeedback(payload(), sender, TO);

  assert.equal(r.status, 202);
  assert.equal(r.body.ok, true);
  assert.equal(r.body.reference, 'ref-123');
  assert.equal(sender.sent.length, 1);

  // The email carries the message; the LOG never does (ADR 0018).
  assert.match(sender.sent[0]!.text, /It crashed on the food board/);
  assert.deepEqual(r.log, {
    status: 202,
    category: 'bug',
    requestId: 'ref-123',
  });
  const logged = JSON.stringify(r.log);
  assert.ok(!logged.includes('crashed'), 'message must not appear in the log');
});

test('empty message: 400 and the relay never sends', async () => {
  const sender = new FakeSender();
  const r = await processFeedback(payload({ message: '   ' }), sender, TO);
  assert.equal(r.status, 400);
  assert.equal(r.body.reason, 'empty');
  assert.equal(sender.sent.length, 0);
});

test('malformed JSON: 400', async () => {
  const sender = new FakeSender();
  const r = await processFeedback('{not json', sender, TO);
  assert.equal(r.status, 400);
  assert.equal(r.body.reason, 'malformed');
  assert.equal(sender.sent.length, 0);
});

test('oversized body: 413 before parsing', async () => {
  const sender = new FakeSender();
  const big = JSON.stringify({ category: 'bug', message: 'x'.repeat(20000) });
  const r = await processFeedback(big, sender, TO);
  assert.equal(r.status, 413);
  assert.equal(sender.sent.length, 0);
});

test('sender failure: 502, error is not logged', async () => {
  const sender = new FakeSender();
  sender.shouldThrow = true;
  const r = await processFeedback(payload(), sender, TO);
  assert.equal(r.status, 502);
  assert.equal(r.body.reason, 'relayFailed');
  const logged = JSON.stringify(r.log);
  assert.ok(!logged.includes('provider down'), 'provider error must not leak to log');
  assert.ok(!logged.includes('crashed'), 'payload must not leak to log');
});
