import { test } from 'node:test';
import assert from 'node:assert/strict';

import { buildEmail } from '../src/email.ts';
import type { CleanFeedback } from '../src/validate.ts';

function clean(over: Partial<CleanFeedback> = {}): CleanFeedback {
  return {
    category: 'bug',
    message: 'The cat tile says dog',
    appVersion: '1.2.3',
    osVersion: 'android 14',
    locale: 'en',
    clientNonce: 'abc123',
    ...over,
  };
}

const TO = 'lighthouse@kinderhorizon.org';

test('subject carries category and reference, addressed to the inbox', () => {
  const m = buildEmail(clean(), TO);
  assert.equal(m.to, TO);
  assert.match(m.subject, /bug/);
  assert.match(m.subject, /abc123/);
});

test('body is plain text and contains the message + triage context', () => {
  const m = buildEmail(clean(), TO);
  assert.match(m.text, /The cat tile says dog/);
  assert.match(m.text, /App version: 1\.2\.3/);
  assert.match(m.text, /OS: android 14/);
  assert.match(m.text, /No data is stored\./);
});

test('replyTo is set only when a contact email was provided', () => {
  assert.equal(buildEmail(clean(), TO).replyTo, undefined);
  const withEmail = buildEmail(clean({ contactEmail: 'p@example.com' }), TO);
  assert.equal(withEmail.replyTo, 'p@example.com');
  assert.match(withEmail.text, /Reply to: p@example\.com/);
});
