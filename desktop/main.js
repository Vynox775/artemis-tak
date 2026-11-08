// Artemis TAK overlay: shows the live site in a see-through window on top of Roblox.
//   F8  = lock / unlock (locked = clicks go through to the game)
//   F9  = hide / show
//   F10 = bigger, Shift+F10 = smaller (remembered)
//   Ctrl+Shift+Q = close
const { app, BrowserWindow, globalShortcut, ipcMain, screen, shell } = require('electron');
const path = require('path');

const SITE = 'https://artemis-tak.vercel.app/play';
const BASE_W = 860, BASE_H = 600;
const fs = require('fs');
const CFG = () => path.join(app.getPath('userData'), 'size.json');
let zoom = 1;
try { zoom = JSON.parse(fs.readFileSync(CFG(), 'utf8')).zoom || 1; } catch (e) {}

let win = null, locked = false, dragTimer = null;

if (!app.requestSingleInstanceLock()) app.quit();

function applySize() {
  const z = zoom;
  const { x, y } = win.getBounds();
  win.setResizable(true);
  win.setBounds({ x, y, width: Math.round(BASE_W * z), height: Math.round(BASE_H * z) });
  win.setResizable(false);
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
  const b = win.getBounds();
  const w = Math.round(BASE_W * zoom), h = Math.round(BASE_H * zoom); // fixed size so Windows scaling can't grow it
  clearInterval(dragTimer);
  dragTimer = setInterval(() => {
    const p = screen.getCursorScreenPoint();
    const x = b.x + p.x - start.x, y = b.y + p.y - start.y;
    const cur = win.getBounds();
    if (cur.x !== x || cur.y !== y || cur.width !== w || cur.height !== h) win.setBounds({ x, y, width: w, height: h });
  }, 10);
});
ipcMain.on('drag-end', () => { clearInterval(dragTimer); dragTimer = null; });
ipcMain.on('open-external', (_e, url) => { if (/^https?:\/\//.test(url)) shell.openExternal(url); });

app.whenReady().then(() => {
  create();
  globalShortcut.register('F8', () => setLocked(!locked));
  globalShortcut.register('F9', () => { win.isVisible() ? win.hide() : win.showInactive(); });
  globalShortcut.register('CommandOrControl+Shift+Q', () => app.quit());
  const step = d => { zoom = Math.min(2, Math.max(0.4, Math.round((zoom + d) * 10) / 10)); applySize(); try { fs.writeFileSync(CFG(), JSON.stringify({ zoom })); } catch (e) {} };
  globalShortcut.register('F10', () => step(0.1));
  globalShortcut.register('Shift+F10', () => step(-0.1));
});
app.on('will-quit', () => globalShortcut.unregisterAll());
app.on('window-all-closed', () => app.quit());