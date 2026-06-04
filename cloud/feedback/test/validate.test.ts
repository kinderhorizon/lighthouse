import { test } from 'node:test';
import assert from 'node:assert/strict';

import { validateFeedback, MESSAGE_MAX_LENGTH } from '../src/validate.ts';

function base(): Record<string, unknown> {
  return {
    category: 'bug',
    message: 'The voice clip is wrong',
    appVersion: '1.2.3',
    osVersion: 'ios 18.0',
    locale: 'en',
    clientNonce: 'deadbeef',
  };
}

test('accepts a well-formed submission', () => {
  const r = validateFeedback(base());
  assert.equal(r.ok, true);
  if (r.ok) {
    assert.equal(r.value.category, 'bug');
    assert.equal(r.value.message, 'The voice clip is wrong');
    assert.equal(r.value.contactEmail, undefined);
  }
});

test('rejects an unknown category', () => {
  const r = validateFeedback({ ...base(), category: 'spam' });
  assert.deepEqual(r, { ok: false, reason: 'category' });
});

test('rejects an empty / whitespace-only message', () => {
  const r = validateFeedback({ ...base(), message: '   ' });
  assert.deepEqual(r, { ok: false, reason: 'empty' });
});

test('rejects an over-long message', () => {
  const r = validateFeedback({ ...base(), message: 'x'.repeat(MESSAGE_MAX_LENGTH + 1) });
  assert.deepEqual(r, { ok: false, reason: 'tooLong' });
});

test('preserves newlines in the message but strips CR and other controls', () => {
  const r = validateFeedback({ ...base(), message: 'para1\r\nline2\u0000end' });
  assert.equal(r.ok, true);
  if (r.ok) {
    // Newlines survive (a multi-paragraph report stays readable)...
    assert.ok(r.value.message.includes('\n'), 'newlines preserved');
    // ...but CR and NUL/other control chars do not.
    assert.ok(!r.value.message.includes('\r'), 'CR stripped');
    assert.ok(!r.value.message.includes('\u0000'), 'NUL stripped');
    assert.equal(r.value.message, 'para1\nline2end');
  }
});

test('still strips control characters from single-line triage fields', () => {
  const r = validateFeedback({ ...base(), locale: 'e\r\nn' });
  assert.equal(r.ok, true);
  if (r.ok) assert.ok(!/[\r\n]/.test(r.value.locale), 'triage stays single-line');
});

test('accepts a plausible contact email', () => {
  const r = validateFeedback({ ...base(), contactEmail: 'parent@example.com' });
  assert.equal(r.ok, true);
  if (r.ok) assert.equal(r.value.contactEmail, 'parent@example.com');
});

test('rejects a header-injection contact email (CRLF)', () => {
  const r = validateFeedback({
    ...base(),
    contactEmail: 'a@b.com\r\nBcc: evil@x.com',
  });
  assert.deepEqual(r, { ok: false, reason: 'email' });
});

test('rejects an email with a second recipient via comma', () => {
  const r = validateFeedback({ ...base(), contactEmail: 'a@b.com, c@d.com' });
  assert.deepEqual(r, { ok: false, reason: 'email' });
});

test('missing triage fields default to "unknown", never throw', () => {
  const r = validateFeedback({ category: 'other', message: 'hi' });
  assert.equal(r.ok, true);
  if (r.ok) {
    assert.equal(r.value.appVersion, 'unknown');
    assert.equal(r.value.osVersion, 'unknown');
    assert.equal(r.value.locale, 'unknown');
    assert.equal(r.value.clientNonce, 'unknown');
  }
});

test('rejects a non-object body', () => {
  assert.deepEqual(validateFeedback('nope'), { ok: false, reason: 'malformed' });
  assert.deepEqual(validateFeedback([1, 2]), { ok: false, reason: 'malformed' });
  assert.deepEqual(validateFeedback(null), { ok: false, reason: 'malformed' });
});
