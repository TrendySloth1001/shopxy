"use strict";

/**
 * Bust Chromium's HTTP/code cache when the packaged app version changes.
 *
 * The shell always boots the bundled Next server on a FIXED loopback origin
 * (http://127.0.0.1:31010) so the httpOnly cookie origin stays stable across
 * relaunches. The trade-off: Chromium caches Next's `/_next/static` assets as
 * immutable (1-year) per origin. After an in-place upgrade to a new build, that
 * cache keeps serving the PREVIOUS build's assets/RSC for the same origin — so
 * the user sees the old UI even though the new code is on disk.
 *
 * Fix: stamp the last-run app version in userData. On boot, if it differs (or is
 * missing — first run after this ships), clear the network + code cache once.
 * Cookies / Local Storage / session are NOT touched, so the login survives.
 */
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
    return null; // missing/corrupt — treat as "upgraded".
  }
}

function writeVersion(userDataDir, version) {
  try {
    fs.writeFileSync(stampPath(userDataDir), JSON.stringify({ version }), "utf8");
  } catch {
    /* best-effort; a failed stamp just re-clears next launch */
  }
}

/**
 * Clear the asset cache iff the version changed. Returns true if it cleared.
 *  - userDataDir: app.getPath("userData")
 *  - version:     app.getVersion()
 *  - ses:         an Electron Session (session.defaultSession)
 */
async function clearCacheOnUpgrade({ userDataDir, version, ses } = {}) {
  if (!userDataDir || !version || !ses) return false;
  const previous = readLastVersion(userDataDir);
  if (previous === version) return false;

  try {
    // HTTP cache (the immutable `/_next/static` assets) + compiled-JS code cache.
    await ses.clearCache();
    await ses.clearCodeCaches({ urls: [] });
    // Defensive: drop any service-worker / CacheStorage buckets too. The storage
    // filter is explicit so cookies + Local Storage (the auth session) are NOT
    // cleared — the user stays logged in across the upgrade.
    await ses.clearStorageData({ storages: ["serviceworkers", "cachestorage"] });
    console.log(
      `[cache-bust] version ${previous ?? "(none)"} -> ${version}: cleared asset cache`,
    );
  } catch (err) {
    // If the clear fails we still stamp; worst case the user hard-reloads once.
    console.error("[cache-bust] clear failed:", err && err.message ? err.message : err);
  }
  writeVersion(userDataDir, version);
  return true;
}

module.exports = { clearCacheOnUpgrade };
