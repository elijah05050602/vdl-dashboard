const test = require('node:test');
const assert = require('node:assert');
const { normalizeUrl, isAllowedServerUrl } = require('../src/url');

test('adds http:// for localhost when the scheme is missing', () => {
  assert.strictEqual(normalizeUrl('localhost:3000'), 'http://localhost:3000');
  assert.strictEqual(normalizeUrl('127.0.0.1:3000'), 'http://127.0.0.1:3000');
});

test('adds https:// for any other host when the scheme is missing', () => {
  assert.strictEqual(normalizeUrl('dashboard.example.com'), 'https://dashboard.example.com');
  assert.strictEqual(normalizeUrl('192.168.1.20:3000'), 'https://192.168.1.20:3000');
});

test('keeps https, a sub path, and drops the trailing slash', () => {
  assert.strictEqual(normalizeUrl(' https://dashboard.example.com/ '), 'https://dashboard.example.com');
  assert.strictEqual(normalizeUrl('https://example.com/dashboard/'), 'https://example.com/dashboard');
});

test('allows plain http only for localhost', () => {
  assert.strictEqual(normalizeUrl('http://localhost:3000/'), 'http://localhost:3000');
  assert.strictEqual(normalizeUrl('http://[::1]:3000'), 'http://[::1]:3000');
  assert.throws(() => normalizeUrl('http://dashboard.example.com'), /Use https:\/\//);
  assert.throws(() => normalizeUrl('http://localhost.evil.com'), /Use https:\/\//);
  assert.throws(() => normalizeUrl('http://192.168.1.20:3000'), /Use https:\/\//);
});

test('rejects empty input, credentials and other schemes', () => {
  assert.throws(() => normalizeUrl('  '), /enter the server address/);
  assert.throws(() => normalizeUrl('https://user:pw@example.com'), /user name and password/);
  assert.throws(() => normalizeUrl('file:///C:/secret'), /must start with https/);
  assert.throws(() => normalizeUrl('javascript://alert(1)'), /must start with https/);
});

test('re-checks a saved address on start', () => {
  assert.strictEqual(isAllowedServerUrl('https://dashboard.example.com'), true);
  assert.strictEqual(isAllowedServerUrl('http://dashboard.example.com'), false);
  assert.strictEqual(isAllowedServerUrl(undefined), false);
});
