const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]']);

function isLocalHost(hostname) {
  return LOCAL_HOSTS.has(hostname.toLowerCase());
}

function normalizeUrl(input) {
  let value = String(input || '').trim();
  if (!value) throw new Error('Please enter the server address.');
  if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(value)) {
    const host = value.split(/[/:?#]/)[0];
    value = `${isLocalHost(host) ? 'http' : 'https'}://${value}`;
  }
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error('That does not look like a web address.');
  }
  if (url.username || url.password) throw new Error('Leave the user name and password out of the address.');
  if (url.protocol === 'http:' && !isLocalHost(url.hostname)) {
    throw new Error('Use https:// for an online server, so passwords and client data are encrypted. Plain http:// only works for localhost.');
  }
  if (!['http:', 'https:'].includes(url.protocol)) throw new Error('The address must start with https://');
  url.hash = '';
  return url.toString().replace(/\/+$/, '');
}

function isAllowedServerUrl(value) {
  try {
    return normalizeUrl(value) === value;
  } catch {
    return false;
  }
}

module.exports = { normalizeUrl, isAllowedServerUrl, isLocalHost };
