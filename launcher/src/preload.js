const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('wallborn', {
  getConfig: () => ipcRenderer.invoke('config:get'),
  checkRelease: () => ipcRenderer.invoke('release:check'),
  updateBuild: () => ipcRenderer.invoke('build:update'),
  launchBuild: () => ipcRenderer.invoke('build:launch'),
  openUserData: () => ipcRenderer.invoke('paths:open-user-data'),
});