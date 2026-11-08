const { contextBridge, ipcRenderer } = require('electron');

// This is what index.html looks for to switch into overlay mode.
contextBridge.exposeInMainWorld('rotak', {
  send: (ch) => { if (ch === 'drag-start' || ch === 'drag-end') ipcRenderer.send(ch); },
  onLocked: (fn) => ipcRenderer.on('locked', (_e, v) => fn(v)),
  onUpdate: () => {},          // updates come from the website itself
  installUpdate: () => {},
  openExternal: (url) => ipcRenderer.send('open-external', String(url)),
});
