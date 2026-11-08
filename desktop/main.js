// Artemis TAK overlay: shows the live site in a see-through window on top of Roblox.
//   F8  = lock / unlock (locked = clicks go through to the game)
//   F9  = hide / show
//   F10 = change size
//   Ctrl+Shift+Q = close
const { app, BrowserWindow, globalShortcut, ipcMain, screen, shell } = require('electron');
const path = require('path');

const SITE = 'https://artemis-tak.vercel.app/play';
const BASE_W = 860, BASE_H = 600;
const SIZES = [0.8, 1, 1.25, 1.5];

let win = null, locked = false, sizeIdx = 1, dragTimer = null;

if (!app.requestSingleInstanceLock()) app.quit();

function applySize() {
  const z = SIZES[sizeIdx];
  const [x, y] = win.getPosition();
  win.setResizable(true);
  win.setSize(Math.round(BASE_W * z), Math.round(BASE_H * z));
  win.setResizable(false);
  win.setPosition(x, y);
  win.webContents.setZoomFactor(z);
}

function setLocked(v) {
  locked = v;
  win.setIgnoreMouseEvents(locked, { forward: true });
  win.webContents.send('locked', locked);
}

function create() {
  win = new BrowserWindow({
    width: BASE_W, height: BASE_H,
    transparent: true, frame: false, resizable: false,
    hasShadow: false, backgroundColor: '#00000000',
    alwaysOnTop: true, fullscreenable: false,
    title: 'Artemis TAK',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, nodeIntegration: false },
  });
  win.setAlwaysOnTop(true, 'screen-saver');
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  win.loadURL(SITE);
  win.webContents.on('did-finish-load', () => { applySize(); win.webContents.send('locked', locked); });
  // Links open in the normal browser, not inside the overlay
  win.webContents.setWindowOpenHandler(({ url }) => { shell.openExternal(url); return { action: 'deny' }; });
}

ipcMain.on('drag-start', () => {
  const start = screen.getCursorScreenPoint();
  const [wx, wy] = win.getPosition();
  clearInterval(dragTimer);
  dragTimer = setInterval(() => {
    const p = screen.getCursorScreenPoint();
    win.setPosition(wx + p.x - start.x, wy + p.y - start.y);
  }, 10);
});
ipcMain.on('drag-end', () => { clearInterval(dragTimer); dragTimer = null; });
ipcMain.on('open-external', (_e, url) => { if (/^https?:\/\//.test(url)) shell.openExternal(url); });

app.whenReady().then(() => {
  create();
  globalShortcut.register('F8', () => setLocked(!locked));
  globalShortcut.register('F9', () => { win.isVisible() ? win.hide() : win.showInactive(); });
  globalShortcut.register('CommandOrControl+Shift+Q', () => app.quit());
  globalShortcut.register('F10', () => { sizeIdx = (sizeIdx + 1) % SIZES.length; applySize(); });
});
app.on('will-quit', () => globalShortcut.unregisterAll());
app.on('window-all-closed', () => app.quit());
