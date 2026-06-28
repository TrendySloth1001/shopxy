"use strict";

const { app, BrowserWindow, shell, dialog, ipcMain, session, nativeTheme } = require("electron");
const path = require("node:path");
const { startServer } = require("./lib/server");
const remember = require("./lib/remember");
const theme = require("./lib/theme");
const { clearCacheOnUpgrade } = require("./lib/cache-bust");

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
    // Theme store first — createWindow reads it for the cold-start background.
    theme.configure({ userDataDir: app.getPath("userData") });
    registerThemeIpc();
    // After an in-place upgrade, Chromium would otherwise keep serving the old
    // build's immutable `/_next/static` assets for the fixed loopback origin,
    // leaving the user on a stale UI. Drop the asset cache once per new version
    // (cookies/login are preserved) before the window loads.
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

// Remembered-accounts bridge. All token handling stays in main; the renderer
// only ever receives display profiles + ok/err.
function registerRememberIpc() {
  ipcMain.handle("remember:list", () => remember.listRememberedAccounts());
  ipcMain.handle("remember:current", () => remember.rememberCurrentAccount());
  ipcMain.handle("remember:resume", (_e, id) => remember.resumeAccount(id));
  ipcMain.handle("remember:forget", (_e, id) => remember.forgetAccount(id));
}

// Theme bridge. The renderer owns the visual theme; main only persists it (for
// the next cold start's window background) and re-tints native chrome live.
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

// Open a URL in the OS browser, but only ever https:/mailto: — never file:,
// smb:, or any custom/dangerous protocol the (potentially XSS-controlled)
// renderer might ask us to launch. (NAV-2)
function openExternalSafely(target) {
  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    return; // not a parseable URL — ignore
  }
  if (parsed.protocol === "https:" || parsed.protocol === "mailto:") {
    shell.openExternal(parsed.href);
  }
}

// Pin all in-place navigation to the resolved loopback origin. Without this, a
// BFF XSS/open-redirect could top-navigate the main window to attacker content
// that inherits the privileged `shopxyDesktop` preload bridge (account-resume +
// token side effects). Anything off-origin is cancelled; external https links
// are punted to the OS browser instead. (NAV-1)
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
    if (targetOrigin === allowedOrigin) return; // same-origin app navigation
    event.preventDefault();
    openExternalSafely(target); // vetted https/mailto goes to the OS browser
  };

  win.webContents.on("will-navigate", guard);
  win.webContents.on("will-redirect", guard);

  // Deny every new window/popup; vetted external links open in the OS browser.
  win.webContents.setWindowOpenHandler(({ url: target }) => {
    openExternalSafely(target);
    return { action: "deny" };
  });
}

async function createWindow(url) {
  // Match the saved theme on the very first frame — no white flash before the
  // dark web UI paints. nativeTheme is set here too so OS chrome agrees.
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
      // OS-level renderer sandbox. The preload only uses contextBridge +
      // ipcRenderer.invoke (sandbox-compatible) — all privileged work lives in
      // main — so enabling this just shrinks the blast radius of any renderer
      // compromise without breaking the bridge.
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
