"use strict";

const { app, BrowserWindow, shell, dialog, ipcMain, session } = require("electron");
const path = require("node:path");
const { startServer } = require("./lib/server");
const remember = require("./lib/remember");

// Sets the macOS menu-bar title + about box (instead of "Electron").
app.setName("ShopXY Merchant");

// App entry path. `/login` is the right door: middleware redirects an already
// signed-in session straight to /dashboard, and a guest stays on login. (The
// web app's `/` is a dev design-tokens page, not a real destination.)
const ENTRY_PATH = "/login";

let server = null;
let mainWindow = null;

// Single-instance: focus the existing window instead of booting a 2nd server.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });

  app.whenReady().then(bootstrap);

  app.on("window-all-closed", () => {
    if (process.platform !== "darwin") app.quit();
  });

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0 && server) createWindow(server.url);
  });

  app.on("before-quit", () => {
    if (server) server.stop();
  });
}

async function bootstrap() {
  try {
    server = await startServer({
      userDataDir: app.getPath("userData"),
      isPackaged: app.isPackaged,
      resourcesPath: process.resourcesPath,
    });
    remember.configure({
      serverUrl: server.url,
      apiBaseUrl: server.apiBaseUrl,
      userDataDir: app.getPath("userData"),
      ses: session.defaultSession,
    });
    registerRememberIpc();
    await createWindow(server.url);
  } catch (err) {
    dialog.showErrorBox(
      "ShopXY Merchant — startup failed",
      err instanceof Error ? err.message : String(err),
    );
    app.quit();
  }
}

// Remembered-accounts bridge. All token handling stays in main; the renderer
// only ever receives display profiles + ok/err.
function registerRememberIpc() {
  ipcMain.handle("remember:list", () => remember.listRememberedAccounts());
  ipcMain.handle("remember:current", () => remember.rememberCurrentAccount());
  ipcMain.handle("remember:resume", (_e, id) => remember.resumeAccount(id));
  ipcMain.handle("remember:forget", (_e, id) => remember.forgetAccount(id));
}

async function createWindow(url) {
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 860,
    minWidth: 960,
    minHeight: 640,
    title: "ShopXY Merchant",
    backgroundColor: "#f7f6f2",
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  // External links (Terms / Privacy open with target=_blank) go to the OS
  // browser, never a rogue Electron window.
  mainWindow.webContents.setWindowOpenHandler(({ url: target }) => {
    if (/^https?:\/\//i.test(target)) shell.openExternal(target);
    return { action: "deny" };
  });

  mainWindow.once("ready-to-show", () => mainWindow.show());
  mainWindow.on("closed", () => {
    mainWindow = null;
  });

  await mainWindow.loadURL(`${url}${ENTRY_PATH}`);
}
