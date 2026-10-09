// Run: node --test tests/   (inside website/)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nameError, emailError } from '../src/waitlist/validate.js';
import { INTERESTS, PRICE_RANGES, CONSENT_WORDING } from '../src/waitlist/config.js';

test('names: required and not too long', () => {
  assert.notEqual(nameError(''), '');
  assert.notEqual(nameError('   '), '');
  assert.notEqual(nameError(undefined), '');
  assert.notEqual(nameError('x'.repeat(101)), '');
  assert.equal(nameError('Ada'), '');
  assert.equal(nameError('  Ada Lovelace  '), '');
});

test('emails: required and well formed', () => {
  for (const bad of ['', '  ', 'nope', 'a@b', '@x.com', 'a b@c.com', 'a@b .com', 'x'.repeat(250) + '@e.com']) {
    assert.notEqual(emailError(bad), '', `should reject ${JSON.stringify(bad)}`);
  }
  for (const good of ['a@b.co', ' ada@example.com ', 'first.last+tag@sub.example.co.uk']) {
    assert.equal(emailError(good), '', `should accept ${JSON.stringify(good)}`);
  }
});

test('the Step 2 choices match the brief', () => {
  assert.equal(INTERESTS.length, 7);
  assert.equal(PRICE_RANGES.length, 8);
  assert.equal(PRICE_RANGES.at(-1)[1], 'Not sure yet');
  assert.match(CONSENT_WORDING, /occasional product news, updates and offers from Lofer by email/);
});
