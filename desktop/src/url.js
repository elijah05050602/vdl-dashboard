function normalizeUrl(input) {
  let value = String(input || '').trim();
  if (!value) throw new Error('Please enter the server address.');
  if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(value)) value = `http://${value}`;
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error('That does not look like a web address.');
  }
  if (!['http:', 'https:'].includes(url.protocol)) throw new Error('The address must start with http:// or https://');
  return url.toString().replace(/\/+$/, '');
}

module.exports = { normalizeUrl };
