"use strict";

const { app, BrowserWindow, shell, dialog, ipcMain, session, nativeTheme } = require("electron");
const path = require("node:path");
const { startServer } = require("./lib/server");
const remember = require("./lib/remember");
const theme = require("./lib/theme");
const { clearCacheOnUpgrade } = require("./lib/cache-bust");

app.setName("ShopXY Merchant");

const ENTRY_PATH = "/login";

let server = null;
let mainWindow = null;

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
    theme.configure({ userDataDir: app.getPath("userData") });
    registerThemeIpc();
    await clearCacheOnUpgrade({
      userDataDir: app.getPath("userData"),
      version: app.getVersion(),
      ses: session.defaultSession,
    });

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

function registerRememberIpc() {
  ipcMain.handle("remember:list", () => remember.listRememberedAccounts());
  ipcMain.handle("remember:current", () => remember.rememberCurrentAccount());
  ipcMain.handle("remember:resume", (_e, id) => remember.resumeAccount(id));
  ipcMain.handle("remember:forget", (_e, id) => remember.forgetAccount(id));
}

function registerThemeIpc() {
  ipcMain.handle("theme:set", (_e, value) => {
    if (!theme.isValid(value)) return { ok: false };
    theme.writeTheme(value);
    nativeTheme.themeSource = theme.nativeSourceFor(value);
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.setBackgroundColor(theme.backgroundFor(value));
    }
    return { ok: true };
  });
}

function openExternalSafely(target) {
  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    return;
  }
  if (parsed.protocol === "https:" || parsed.protocol === "mailto:") {
    shell.openExternal(parsed.href);
  }
}

function hardenNavigation(win, serverUrl) {
  const allowedOrigin = new URL(serverUrl).origin;

  const guard = (event, target) => {
    let targetOrigin;
    try {
      targetOrigin = new URL(target).origin;
    } catch {
      event.preventDefault();
      return;
    }
    if (targetOrigin === allowedOrigin) return;
    event.preventDefault();
    openExternalSafely(target);
  };

  win.webContents.on("will-navigate", guard);
  win.webContents.on("will-redirect", guard);

  win.webContents.setWindowOpenHandler(({ url: target }) => {
    openExternalSafely(target);
    return { action: "deny" };
  });
}

async function createWindow(url) {
  const savedTheme = theme.readTheme();
  nativeTheme.themeSource = theme.nativeSourceFor(savedTheme);

  mainWindow = new BrowserWindow({
    width: 1320,
    height: 860,
    minWidth: 960,
    minHeight: 640,
    title: "ShopXY Merchant",
    backgroundColor: theme.backgroundFor(savedTheme),
    show: false,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  hardenNavigation(mainWindow, url);

  mainWindow.once("ready-to-show", () => mainWindow.show());
  mainWindow.on("closed", () => {
    mainWindow = null;
  });

  await mainWindow.loadURL(`${url}${ENTRY_PATH}`);
}
