"use strict";

const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("shopxyDesktop", {
  platform: process.platform,
  isDesktop: true,
  listRememberedAccounts: () => ipcRenderer.invoke("remember:list"),
  rememberCurrentAccount: () => ipcRenderer.invoke("remember:current"),
  resumeAccount: (id) => ipcRenderer.invoke("remember:resume", id),
  forgetAccount: (id) => ipcRenderer.invoke("remember:forget", id),
  setTheme: (theme) => ipcRenderer.invoke("theme:set", theme),
});
