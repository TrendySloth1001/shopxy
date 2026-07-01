"use strict";

/**
 * Theme persistence for the desktop shell.
 *
 * The web layer owns the *visual* theme (it re-tints itself from CSS tokens via
 * the `data-theme` attribute and remembers the choice in localStorage). The main
 * process only needs the value for two native concerns that happen *before* the
 * web app has painted, or *outside* its DOM:
 *
 *   1. the BrowserWindow's `backgroundColor` on cold start — so there's no white
 *      flash before the dark UI loads, and
 *   2. `nativeTheme.themeSource` — so OS chrome (scrollbars, menus, the traffic
 *      lights) matches.
 *
 * We mirror it to a tiny JSON file alongside the remembered-accounts store.
 */

const fs = require("node:fs");
const path = require("node:path");

let _userDataDir = null;

function configure({ userDataDir }) {
  _userDataDir = userDataDir;
}

function storePath() {
  if (!_userDataDir) throw new Error("theme store not configured");
  return path.join(_userDataDir, "theme.json");
}

/** Theme families, kept in sync with merchant-web's src/features/theme/theme.ts
 *  (this shell can't import from the web bundle). Light-family themes map to the
 *  OS "light" source; every other theme is "dark". */
const LIGHT_THEMES = new Set(["light", "beige", "rose", "sage"]);
const DARK_THEMES = new Set(["dark", "oled", "midnight", "nord"]);
const VALID = new Set([...LIGHT_THEMES, ...DARK_THEMES]);

/** Native window background per theme — matches the canvas tokens in the web
 *  app's globals.css so the cold-start frame doesn't flash a different colour. */
const BACKGROUND = {
  light: "#f7f6f2",
  beige: "#ece3d1",
  rose: "#fbf0f2",
  sage: "#eaf1ea",
  dark: "#0f1419",
  oled: "#000000",
  midnight: "#0d1220",
  nord: "#2e3440",
};

function readTheme() {
  try {
    const raw = JSON.parse(fs.readFileSync(storePath(), "utf8"));
    return raw && VALID.has(raw.theme) ? raw.theme : "light";
  } catch {
    return "light";
  }
}

function writeTheme(theme) {
  if (!VALID.has(theme)) return false;
  try {
    fs.writeFileSync(storePath(), JSON.stringify({ theme }), { mode: 0o600 });
    return true;
  } catch {
    return false;
  }
}

function backgroundFor(theme) {
  return BACKGROUND[theme] || BACKGROUND.light;
}

/** Electron `nativeTheme.themeSource` value — the light-family themes report
 *  "light"; every dark-family theme reports "dark", as far as the OS is
 *  concerned (it can't tell deep-slate from navy from true-black). */
function nativeSourceFor(theme) {
  return LIGHT_THEMES.has(theme) ? "light" : "dark";
}

module.exports = {
  configure,
  readTheme,
  writeTheme,
  backgroundFor,
  nativeSourceFor,
  isValid: (t) => VALID.has(t),
};
