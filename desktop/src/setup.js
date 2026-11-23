const form = document.getElementById('form');
const input = document.getElementById('url');
const status = document.getElementById('status');
const testButton = document.getElementById('test');
const saveButton = document.getElementById('save');
const cancelButton = document.getElementById('cancel');
const firstRun = new URLSearchParams(window.location.search).get('firstRun') === '1';

function setStatus(message, kind) {
  status.textContent = message;
  status.className = `status ${kind || ''}`;
}

function busy(on) {
  testButton.disabled = on;
  saveButton.disabled = on;
}

async function runTest() {
  setStatus('Checking…');
  busy(true);
  try {
    const result = await window.dashboardApp.testUrl(input.value);
    setStatus(result.message, result.ok ? 'ok' : 'bad');
    return result.ok;
  } catch (error) {
    setStatus(error.message.replace(/^Error invoking remote method '[^']+': (Error: )?/, ''), 'bad');
    return false;
  } finally {
    busy(false);
  }
}

testButton.addEventListener('click', runTest);
cancelButton.addEventListener('click', () => window.dashboardApp.cancelSettings());

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const reachable = await runTest();
  if (!reachable && !window.confirm('The server could not be reached right now. Save this address anyway?')) return;
  try {
    await window.dashboardApp.saveUrl(input.value);
  } catch (error) {
    setStatus(error.message.replace(/^Error invoking remote method '[^']+': (Error: )?/, ''), 'bad');
  }
});

window.dashboardApp.getConfig().then((config) => {
  input.value = config.serverUrl || config.defaultServerUrl;
  document.getElementById('version').textContent = `Version ${config.version}`;
  if (!firstRun && config.serverUrl) {
    document.getElementById('heading').textContent = 'Server settings';
    document.getElementById('lead').textContent = 'Change the dashboard server this PC connects to.';
    cancelButton.hidden = false;
  }
  input.focus();
  input.select();
});
