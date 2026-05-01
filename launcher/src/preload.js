const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('wallborn', {
  getConfig: () => ipcRenderer.invoke('config:get'),
  setToken: (token) => ipcRenderer.invoke('config:set-token', token),
  checkRelease: () => ipcRenderer.invoke('release:check'),
  updateBuild: () => ipcRenderer.invoke('build:update'),
  launchBuild: () => ipcRenderer.invoke('build:launch'),
  openUserData: () => ipcRenderer.invoke('paths:open-user-data'),
});