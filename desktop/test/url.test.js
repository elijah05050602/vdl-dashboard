const test = require('node:test');
const assert = require('node:assert');
const { normalizeUrl } = require('../src/url');

test('adds http:// when the scheme is missing', () => {
  assert.strictEqual(normalizeUrl('localhost:3000'), 'http://localhost:3000');
});

test('keeps https and drops the trailing slash', () => {
  assert.strictEqual(normalizeUrl(' https://dashboard.example.com/ '), 'https://dashboard.example.com');
});

test('keeps a sub path', () => {
  assert.strictEqual(normalizeUrl('https://example.com/dashboard/'), 'https://example.com/dashboard');
});

test('rejects empty input', () => {
  assert.throws(() => normalizeUrl('  '), /enter the server address/);
});

test('rejects other schemes', () => {
  assert.throws(() => normalizeUrl('file:///C:/secret'), /http:\/\/ or https:\/\//);
  assert.throws(() => normalizeUrl('javascript://alert(1)'), /http:\/\/ or https:\/\//);
});
