"use strict";

const { contextBridge, ipcRenderer } = require("electron");

// Locked-down bridge. The remembered-accounts API never exposes tokens — the
// renderer gets display profiles + ok/err only; the main process holds the
// device-remember credentials (keychain-encrypted) and injects session cookies.
contextBridge.exposeInMainWorld("shopxyDesktop", {
  platform: process.platform,
  isDesktop: true,
  /** -> Array<{ id, name, email, avatarUrl }> */
  listRememberedAccounts: () => ipcRenderer.invoke("remember:list"),
  /** Call after a fresh password login to remember this account on the device. */
  rememberCurrentAccount: () => ipcRenderer.invoke("remember:current"),
  /** One-tap resume by account id -> { ok } | { ok:false, error, removed? } */
  resumeAccount: (id) => ipcRenderer.invoke("remember:resume", id),
  /** Remove + revoke a remembered account -> { ok } */
  forgetAccount: (id) => ipcRenderer.invoke("remember:forget", id),
  /** Persist the chosen theme ("light" | "dark" | "oled") and re-tint the
   *  native window + OS chrome to match -> { ok }. */
  setTheme: (theme) => ipcRenderer.invoke("theme:set", theme),
});
