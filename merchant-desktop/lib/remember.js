"use strict";

/**
 * Remembered-accounts store for the desktop app. The device-remember token
 * NEVER reaches the renderer/web JS: it's held here in the main process,
 * encrypted at rest with the OS keychain (Electron safeStorage), and used to
 * call the backend + inject fresh session cookies into the Electron session.
 * The renderer only ever gets the display profile (name/email/avatar).
 */
const fs = require("node:fs");
const path = require("node:path");
const { safeStorage } = require("electron");

let _serverUrl = null; // http://127.0.0.1:PORT (cookie origin)
let _apiBaseUrl = null; // backend base, no trailing slash
let _userDataDir = null;
let _ses = null; // Electron session for cookie read/write

function configure({ serverUrl, apiBaseUrl, userDataDir, ses }) {
  _serverUrl = serverUrl;
  _apiBaseUrl = (apiBaseUrl || "").replace(/\/+$/, "");
  _userDataDir = userDataDir;
  _ses = ses;
}

function storePath() {
  return path.join(_userDataDir, "remembered-accounts.json");
}

function readStore() {
  try {
    return JSON.parse(fs.readFileSync(storePath(), "utf8"));
  } catch {
    return { accounts: [] };
  }
}

function writeStore(store) {
  fs.mkdirSync(path.dirname(storePath()), { recursive: true });
  fs.writeFileSync(storePath(), JSON.stringify(store), { mode: 0o600 });
}

function sealToken(token) {
  if (safeStorage.isEncryptionAvailable()) {
    return { enc: safeStorage.encryptString(token).toString("base64") };
  }
  // Keychain unavailable (rare) — last resort, still inside the user-only store.
  return { plain: token };
}

function openToken(acct) {
  if (acct.enc) {
    try {
      return safeStorage.decryptString(Buffer.from(acct.enc, "base64"));
    } catch {
      return null;
    }
  }
  return acct.plain ?? null;
}

async function backend(pathname, { method = "POST", body, bearer } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (bearer) headers.Authorization = `Bearer ${bearer}`;
  return fetch(`${_apiBaseUrl}${pathname}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
}

async function getCookie(name) {
  const cookies = await _ses.cookies.get({ url: _serverUrl, name });
  return cookies[0]?.value ?? null;
}

async function setSessionCookie(name, value) {
  await _ses.cookies.set({
    url: _serverUrl,
    name,
    value,
    httpOnly: true,
    secure: false, // loopback http origin
    sameSite: "lax",
    path: "/",
    expirationDate: Math.floor(Date.now() / 1000) + 7 * 24 * 3600,
  });
}

function profileOf(u) {
  return { id: u.id, name: u.name, email: u.email, avatarUrl: u.avatarUrl ?? null };
}

function upsert(store, profile, token) {
  const rest = store.accounts.filter((a) => a.id !== profile.id);
  return { accounts: [{ ...profile, ...sealToken(token) }, ...rest] };
}

/** After a fresh password login: mint + store a remember credential for this
 *  device. Reads the just-set access cookie from the session (never the web). */
async function rememberCurrentAccount() {
  const access = await getCookie("sxm_access");
  if (!access) return { ok: false };
  const meRes = await backend("/auth/me", { method: "GET", bearer: access });
  if (!meRes.ok) return { ok: false };
  const me = await meRes.json();
  const remRes = await backend("/auth/remember", {
    body: { label: `${process.platform} desktop` },
    bearer: access,
  });
  if (!remRes.ok) return { ok: false };
  const { rememberToken } = await remRes.json();
  writeStore(upsert(readStore(), profileOf(me), rememberToken));
  return { ok: true };
}

/** Profiles only — no tokens — for the login-screen account cards. */
function listRememberedAccounts() {
  return readStore().accounts.map((a) => ({
    id: a.id,
    name: a.name,
    email: a.email,
    avatarUrl: a.avatarUrl ?? null,
  }));
}

/** One-tap resume: exchange the stored token for a fresh session and inject
 *  the cookies. Drops the card if the token is dead. */
async function resumeAccount(id) {
  const store = readStore();
  const acct = store.accounts.find((a) => a.id === id);
  if (!acct) return { ok: false, error: "Account not found." };
  const token = openToken(acct);
  if (!token) return { ok: false, error: "This saved sign-in is unavailable." };

  const res = await backend("/auth/remember-login", { body: { rememberToken: token } });
  if (!res.ok) {
    writeStore({ accounts: store.accounts.filter((a) => a.id !== id) });
    let error = "This saved sign-in is no longer valid.";
    try {
      error = (await res.json()).error ?? error;
    } catch {
      /* keep default */
    }
    return { ok: false, error, removed: true };
  }
  const data = await res.json();
  await setSessionCookie("sxm_access", data.accessToken);
  await setSessionCookie("sxm_refresh", data.refreshToken);
  writeStore(upsert(store, profileOf(data.user), data.rememberToken));
  return { ok: true };
}

/** "Remove this account" — revoke server-side + drop locally. */
async function forgetAccount(id) {
  const store = readStore();
  const acct = store.accounts.find((a) => a.id === id);
  if (acct) {
    const token = openToken(acct);
    if (token) {
      try {
        await backend("/auth/remember/forget", { body: { rememberToken: token } });
      } catch {
        /* best effort */
      }
    }
  }
  writeStore({ accounts: store.accounts.filter((a) => a.id !== id) });
  return { ok: true };
}

module.exports = {
  configure,
  rememberCurrentAccount,
  listRememberedAccounts,
  resumeAccount,
  forgetAccount,
};
