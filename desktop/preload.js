const { contextBridge, ipcRenderer } = require('electron');

// This is what index.html looks for to switch into overlay mode.
contextBridge.exposeInMainWorld('rotak', {
  version: '1.1.0',            // keep in sync with package.json

  send: (ch) => { if (ch === 'drag-start' || ch === 'drag-end') ipcRenderer.send(ch); },
  onLocked: (fn) => ipcRenderer.on('locked', (_e, v) => fn(v)),
  onUpdate: (fn) => ipcRenderer.on('update', (_e, u) => fn(u)),
  installUpdate: () => ipcRenderer.send('install-update'),
  openExternal: (url) => ipcRenderer.send('open-external', String(url)),
});
