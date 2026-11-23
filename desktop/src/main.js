const { app, BrowserWindow, Menu, ipcMain, net, protocol, shell, session } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
const { normalizeUrl, isAllowedServerUrl } = require('./url');

const APP_NAME = 'VDL Dashboard';
const APP_ID = 'com.vdl.dashboard';
const FALLBACK_SERVER_URL = 'http://localhost:3000';
const RETRY_SECONDS = 15;
const LOCAL_ORIGIN = 'app://local';
const isAppUrl = (url) => Boolean(url) && url.protocol === 'app:' && url.host === 'local';
const LOCAL_PAGES = new Set(['/setup.html', '/offline.html']);
const LOCAL_FILES = {
  '/setup.html': path.join(__dirname, 'setup.html'),
  '/setup.js': path.join(__dirname, 'setup.js'),
  '/offline.html': path.join(__dirname, 'offline.html'),
  '/offline.js': path.join(__dirname, 'offline.js'),
  '/styles.css': path.join(__dirname, 'styles.css'),
  '/icon.png': path.join(__dirname, '..', 'build', 'icon.png'),
};
const CONTENT_TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png' };
const LOCAL_CSP = "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; form-action 'none'; base-uri 'none'; frame-ancestors 'none'";

protocol.registerSchemesAsPrivileged([
  { scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: false } },
]);

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
  return process.env.VDL_DASHBOARD_URL
    || readJson(path.join(__dirname, 'default-server.json')).serverUrl
    || FALLBACK_SERVER_URL;
}

function loadConfig() {
  config = readJson(configPath());
  if (config.serverUrl && !isAllowedServerUrl(config.serverUrl)) delete config.serverUrl;
}

function saveConfig() {
  fs.mkdirSync(path.dirname(configPath()), { recursive: true });
  fs.writeFileSync(configPath(), JSON.stringify(config, null, 2));
}

function parseUrl(value) {
  try {
    return new URL(value);
  } catch {
    return null;
  }
}

function serverOrigin() {
  return config.serverUrl ? parseUrl(config.serverUrl)?.origin : null;
}

function isSameOrigin(target) {
  const origin = serverOrigin();
  return Boolean(origin) && parseUrl(target)?.origin === origin;
}

function isLocalPage(target) {
  const url = parseUrl(target);
  return isAppUrl(url) && LOCAL_PAGES.has(url.pathname);
}

function registerLocalProtocol() {
  protocol.handle('app', async (request) => {
    const url = parseUrl(request.url);
    const file = isAppUrl(url) ? LOCAL_FILES[url.pathname] : null;
    if (!file) return new Response('Not found', { status: 404 });
    const body = await fs.promises.readFile(file);
    return new Response(body, {
      headers: {
        'content-type': CONTENT_TYPES[path.extname(file)],
        'content-security-policy': LOCAL_CSP,
        'x-content-type-options': 'nosniff',
      },
    });
  });
}

function showLocalPage(page, query = {}) {
  const url = new URL(page, LOCAL_ORIGIN);
  Object.entries(query).forEach(([key, value]) => url.searchParams.set(key, value));
  mainWindow.loadURL(url.toString());
}

function openSettings({ firstRun = false } = {}) {
  showLocalPage('/setup.html', { firstRun: firstRun ? '1' : '0' });
}

function openDashboard() {
  if (!config.serverUrl) return openSettings({ firstRun: true });
  mainWindow.loadURL(config.serverUrl);
}

function showOffline(errorDescription, failedUrl) {
  showLocalPage('/offline.html', {
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
    const looksRight = /openproject|vdl dashboard/i.test(body);
    return {
      ok: response.status < 500,
      url,
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
    if (event.sender !== mainWindow?.webContents || !isLocalPage(event.senderFrame?.url)) {
      throw new Error('Not allowed');
    }
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

function openExternal(target) {
  const url = parseUrl(target);
  if (url && ['https:', 'http:', 'mailto:', 'tel:'].includes(url.protocol)) shell.openExternal(url.toString());
}

function buildMenu() {
  const template = [
    {
      label: 'File',
      submenu: [
        { label: 'Server settings…', accelerator: 'CmdOrCtrl+,', click: () => openSettings() },
        {
          label: 'Open in web browser',
          click: () => openExternal(isSameOrigin(mainWindow.webContents.getURL()) ? mainWindow.webContents.getURL() : config.serverUrl),
        },
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
        { label: `${APP_NAME} ${app.getVersion()}`, enabled: false },
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

const secureWebPreferences = {
  contextIsolation: true,
  nodeIntegration: false,
  nodeIntegrationInSubFrames: false,
  sandbox: true,
  webSecurity: true,
  allowRunningInsecureContent: false,
  webviewTag: false,
  spellcheck: true,
};

function lockDownNavigation(contents) {
  contents.setWindowOpenHandler(({ url }) => {
    if (isSameOrigin(url)) {
      return {
        action: 'allow',
        overrideBrowserWindowOptions: { autoHideMenuBar: true, webPreferences: secureWebPreferences },
      };
    }
    openExternal(url);
    return { action: 'deny' };
  });

  const guardNavigation = (event, url) => {
    if (isSameOrigin(url)) return;
    event.preventDefault();
    openExternal(url);
  };
  contents.on('will-navigate', guardNavigation);
  contents.on('will-redirect', guardNavigation);
}

function createWindow() {
  mainWindow = new BrowserWindow({
    ...restoreBounds(),
    minWidth: 900,
    minHeight: 600,
    title: APP_NAME,
    icon: path.join(__dirname, '..', 'build', 'icon.png'),
    backgroundColor: '#2E2829',
    show: false,
    webPreferences: { ...secureWebPreferences, preload: path.join(__dirname, 'preload.js') },
  });

  if (config.windowMaximized) mainWindow.maximize();
  mainWindow.once('ready-to-show', () => mainWindow.show());
  mainWindow.on('close', rememberBounds);

  const { webContents } = mainWindow;
  lockDownNavigation(webContents);

  webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL, isMainFrame) => {
    if (!isMainFrame || errorCode === -3 || isLocalPage(validatedURL)) return;
    showOffline(errorDescription, validatedURL);
  });

  webContents.on('page-title-updated', (event, title) => {
    event.preventDefault();
    const clean = isLocalPage(webContents.getURL()) ? '' : title;
    mainWindow.setTitle(clean ? `${clean} – ${APP_NAME}` : APP_NAME);
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

  app.on('web-contents-created', (_event, contents) => {
    contents.on('will-attach-webview', (event) => event.preventDefault());
    if (contents.getType() === 'window' && mainWindow && contents !== mainWindow.webContents) {
      lockDownNavigation(contents);
    }
  });

  app.whenReady().then(() => {
    app.setAppUserModelId(APP_ID);
    registerLocalProtocol();
    session.defaultSession.setPermissionRequestHandler((webContents, permission, callback) => {
      const allowed = ['clipboard-sanitized-write', 'notifications', 'fullscreen'];
      callback(allowed.includes(permission) && isSameOrigin(webContents.getURL()));
    });
    session.defaultSession.setPermissionCheckHandler((_webContents, permission, requestingOrigin) => (
      ['clipboard-sanitized-write', 'notifications', 'fullscreen'].includes(permission) && requestingOrigin === serverOrigin()
    ));
    loadConfig();
    registerIpc();
    buildMenu();
    createWindow();
  });

  app.on('window-all-closed', () => app.quit());
}
