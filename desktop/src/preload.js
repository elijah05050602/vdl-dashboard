const { contextBridge, ipcRenderer } = require('electron');

if (window.location.protocol === 'app:' && window.location.host === 'local') {
  contextBridge.exposeInMainWorld('dashboardApp', {
    getConfig: () => ipcRenderer.invoke('app:get-config'),
    testUrl: (url) => ipcRenderer.invoke('app:test-url', url),
    saveUrl: (url) => ipcRenderer.invoke('app:save-url', url),
    retry: () => ipcRenderer.invoke('app:retry'),
    openSettings: () => ipcRenderer.invoke('app:open-settings'),
    cancelSettings: () => ipcRenderer.invoke('app:cancel-settings'),
  });
}
