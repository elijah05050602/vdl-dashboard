const { app, BrowserWindow, Menu, ipcMain, net, shell, session } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { normalizeUrl } = require('./url');

const FALLBACK_SERVER_URL = 'http://localhost:3000';
const RETRY_SECONDS = 15;

let mainWindow = null;
let config = {};

const configPath = () => path.join(app.getPath('userData'), 'config.json');

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return {};
  }
}

function defaultServerUrl() {
  return process.env.LAW_FIRM_DASHBOARD_URL
    || readJson(path.join(__dirname, 'default-server.json')).serverUrl
    || FALLBACK_SERVER_URL;
}

function loadConfig() {
  config = readJson(configPath());
}

function saveConfig() {
  fs.mkdirSync(path.dirname(configPath()), { recursive: true });
  fs.writeFileSync(configPath(), JSON.stringify(config, null, 2));
}

function serverOrigin() {
  try {
    return new URL(config.serverUrl).origin;
  } catch {
    return null;
  }
}

function isLocalPage(frameUrl) {
  return typeof frameUrl === 'string' && frameUrl.startsWith('file://');
}

function showLocalPage(page, query = {}) {
  mainWindow.loadFile(path.join(__dirname, page), { query });
}

function openSettings({ firstRun = false } = {}) {
  showLocalPage('setup.html', { firstRun: firstRun ? '1' : '0' });
}

function openDashboard() {
  if (!config.serverUrl) return openSettings({ firstRun: true });
  mainWindow.loadURL(config.serverUrl);
}

function showOffline(errorDescription, failedUrl) {
  showLocalPage('offline.html', {
    error: errorDescription || 'The server did not respond.',
    url: failedUrl || config.serverUrl || '',
    retry: String(RETRY_SECONDS),
  });
}

async function testConnection(rawUrl) {
  const url = normalizeUrl(rawUrl);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await net.fetch(url, { signal: controller.signal, redirect: 'follow' });
    const body = await response.text();
    const looksRight = /openproject|law firm dashboard/i.test(body);
    return {
      ok: response.status < 500,
      url,
      status: response.status,
      message: looksRight
        ? 'Connected. The dashboard is answering at this address.'
        : `The server answered (status ${response.status}), but it does not look like the dashboard. Double-check the address.`,
    };
  } catch (error) {
    return {
      ok: false,
      url,
      message: error.name === 'AbortError'
        ? 'No answer after 8 seconds. Is the server running and is the address right?'
        : `Could not reach the server: ${error.message}`,
    };
  } finally {
    clearTimeout(timer);
  }
}

function registerIpc() {
  const guard = (handler) => (event, ...args) => {
    if (!isLocalPage(event.senderFrame?.url)) throw new Error('Not allowed');
    return handler(...args);
  };

  ipcMain.handle('app:get-config', guard(() => ({
    serverUrl: config.serverUrl || '',
    defaultServerUrl: defaultServerUrl(),
    version: app.getVersion(),
  })));

  ipcMain.handle('app:test-url', guard((url) => testConnection(url)));

  ipcMain.handle('app:save-url', guard((url) => {
    config.serverUrl = normalizeUrl(url);
    saveConfig();
    openDashboard();
    return config.serverUrl;
  }));

  ipcMain.handle('app:retry', guard(() => openDashboard()));
  ipcMain.handle('app:open-settings', guard(() => openSettings()));
  ipcMain.handle('app:cancel-settings', guard(() => openDashboard()));
}

function buildMenu() {
  const template = [
    {
      label: 'File',
      submenu: [
        { label: 'Server settings…', accelerator: 'CmdOrCtrl+,', click: () => openSettings() },
        { label: 'Open in web browser', click: () => config.serverUrl && shell.openExternal(mainWindow.webContents.getURL().startsWith('http') ? mainWindow.webContents.getURL() : config.serverUrl) },
        { type: 'separator' },
        { role: 'quit', label: 'Exit' },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' }, { role: 'redo' }, { type: 'separator' },
        { role: 'cut' }, { role: 'copy' }, { role: 'paste' }, { role: 'selectAll' },
      ],
    },
    {
      label: 'View',
      submenu: [
        { label: 'Home', accelerator: 'Alt+Home', click: () => openDashboard() },
        { label: 'Back', accelerator: 'Alt+Left', click: () => mainWindow.webContents.navigationHistory.goBack() },
        { label: 'Forward', accelerator: 'Alt+Right', click: () => mainWindow.webContents.navigationHistory.goForward() },
        { type: 'separator' },
        { role: 'reload' }, { role: 'forceReload' },
        { type: 'separator' },
        { role: 'resetZoom' }, { role: 'zoomIn' }, { role: 'zoomOut' },
        { type: 'separator' },
        { role: 'togglefullscreen' },
        { role: 'toggleDevTools', visible: !app.isPackaged },
      ],
    },
    {
      label: 'Help',
      submenu: [
        { label: `Law Firm Dashboard ${app.getVersion()}`, enabled: false },
        { label: 'Server settings…', click: () => openSettings() },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function restoreBounds() {
  const bounds = config.windowBounds || {};
  return {
    width: bounds.width || 1400,
    height: bounds.height || 900,
    x: bounds.x,
    y: bounds.y,
  };
}

function rememberBounds() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  config.windowMaximized = mainWindow.isMaximized();
  if (!mainWindow.isMaximized() && !mainWindow.isMinimized()) config.windowBounds = mainWindow.getBounds();
  saveConfig();
}

function isSameOrigin(target) {
  try {
    return new URL(target).origin === serverOrigin();
  } catch {
    return false;
  }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    ...restoreBounds(),
    minWidth: 900,
    minHeight: 600,
    title: 'Law Firm Dashboard',
    icon: path.join(__dirname, '..', 'build', 'icon.png'),
    backgroundColor: '#0f2140',
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: true,
    },
  });

  if (config.windowMaximized) mainWindow.maximize();
  mainWindow.once('ready-to-show', () => mainWindow.show());
  mainWindow.on('close', rememberBounds);

  const { webContents } = mainWindow;

  webContents.setWindowOpenHandler(({ url }) => {
    if (isSameOrigin(url)) {
      return {
        action: 'allow',
        overrideBrowserWindowOptions: {
          autoHideMenuBar: true,
          webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true },
        },
      };
    }
    if (/^(https?|mailto|tel):/i.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });

  webContents.on('will-navigate', (event, url) => {
    if (url.startsWith('file://') || isSameOrigin(url)) return;
    event.preventDefault();
    if (/^(https?|mailto|tel):/i.test(url)) shell.openExternal(url);
  });

  webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL, isMainFrame) => {
    if (!isMainFrame || errorCode === -3) return;
    showOffline(errorDescription, validatedURL);
  });

  webContents.on('page-title-updated', (event, title) => {
    event.preventDefault();
    const clean = title && !title.startsWith('file://') ? title : '';
    mainWindow.setTitle(clean ? `${clean} – Law Firm Dashboard` : 'Law Firm Dashboard');
  });

  openDashboard();
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  });

  app.whenReady().then(() => {
    app.setAppUserModelId('com.lawfirm.dashboard');
    session.defaultSession.setPermissionRequestHandler((webContents, permission, callback) => {
      const allowed = ['clipboard-sanitized-write', 'notifications', 'fullscreen'];
      callback(allowed.includes(permission) && isSameOrigin(webContents.getURL()));
    });
    loadConfig();
    registerIpc();
    buildMenu();
    createWindow();
  });

  app.on('window-all-closed', () => app.quit());
}
