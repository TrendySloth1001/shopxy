"use strict";

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

const LIGHT_THEMES = new Set(["light", "beige", "rose", "sage"]);
const DARK_THEMES = new Set(["dark", "oled", "midnight", "nord"]);
const VALID = new Set([...LIGHT_THEMES, ...DARK_THEMES]);

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
