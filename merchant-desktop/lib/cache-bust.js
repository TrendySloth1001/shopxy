"use strict";

const fs = require("node:fs");
const path = require("node:path");

function stampPath(userDataDir) {
  return path.join(userDataDir, "last-run-version.json");
}

function readLastVersion(userDataDir) {
  try {
    const raw = fs.readFileSync(stampPath(userDataDir), "utf8");
    const parsed = JSON.parse(raw);
    return typeof parsed.version === "string" ? parsed.version : null;
  } catch {
    return null;
  }
}

function writeVersion(userDataDir, version) {
  try {
    fs.writeFileSync(stampPath(userDataDir), JSON.stringify({ version }), "utf8");
  } catch {
  }
}

async function clearCacheOnUpgrade({ userDataDir, version, ses } = {}) {
  if (!userDataDir || !version || !ses) return false;
  const previous = readLastVersion(userDataDir);
  if (previous === version) return false;

  try {
    await ses.clearCache();
    await ses.clearCodeCaches({ urls: [] });
    await ses.clearStorageData({ storages: ["serviceworkers", "cachestorage"] });
    console.log(
      `[cache-bust] version ${previous ?? "(none)"} -> ${version}: cleared asset cache`,
    );
  } catch (err) {
    console.error("[cache-bust] clear failed:", err && err.message ? err.message : err);
  }
  writeVersion(userDataDir, version);
  return true;
}

module.exports = { clearCacheOnUpgrade };
