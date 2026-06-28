"use strict";

const fs = require("node:fs");
const path = require("node:path");

/**
 * Where the local Next.js server binds. A FIXED loopback port keeps the cookie
 * origin (http://127.0.0.1:PORT) stable across restarts, so httpOnly auth
 * sessions survive relaunch. If it's busy we fall back to the next few ports
 * (the cookie origin changes only in that rare collision case).
 */
const HOST = "127.0.0.1";
const BASE_PORT = 31010;

/**
 * Backend the BFF proxies to. Resolution order (configurable, per the plan):
 *   1. SHOPXY_API_BASE_URL env var (CI / power users)
 *   2. {userData}/config.json -> { "apiBaseUrl": "..." }  (in-app setting)
 *   3. the shared dev tunnel default (same value merchant-web defaults to)
 */
const DEFAULT_API_BASE_URL = "https://qjhcp0ph-3003.inc1.devtunnels.ms";

/**
 * Allowlist of backend hosts the app may talk to. The apiBaseUrl drives every
 * authenticated request in remember.js (carrying the user's bearer + remember
 * tokens) and is injected as API_BASE_URL into the Next BFF, so an unvalidated
 * override from env or {userData}/config.json would let a local attacker silently
 * repoint all token traffic at a hostile backend (CONFIG-1). Overrides are only
 * honored when https + an allowlisted host; loopback http is allowed in dev only.
 */
const ALLOWED_API_HOSTS = ["qjhcp0ph-3003.inc1.devtunnels.ms"];
const LOOPBACK_HOSTS = ["localhost", "127.0.0.1", "[::1]"];

function isDevEnv() {
  return process.env.NODE_ENV !== "production" || process.env.SHOPXY_DESKTOP_DEV === "1";
}

/** Returns the sanitized base URL if it passes the allowlist, else null. */
function validateApiBaseUrl(value) {
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    return null;
  }
  // Loopback http(s) only when running in dev — never in a packaged prod build.
  if (LOOPBACK_HOSTS.includes(parsed.hostname)) {
    return isDevEnv() ? value.replace(/\/+$/, "") : null;
  }
  // Everything else must be https on an allowlisted host.
  if (parsed.protocol !== "https:") return null;
  if (!ALLOWED_API_HOSTS.includes(parsed.hostname)) return null;
  return value.replace(/\/+$/, "");
}

function resolveApiBaseUrl(userDataDir) {
  const fromEnv = process.env.SHOPXY_API_BASE_URL;
  if (fromEnv && fromEnv.trim()) {
    const ok = validateApiBaseUrl(fromEnv.trim());
    if (ok) return ok;
    // Reject (don't honor) an out-of-allowlist override — fall back to default.
  }

  if (userDataDir) {
    try {
      const raw = fs.readFileSync(path.join(userDataDir, "config.json"), "utf8");
      const cfg = JSON.parse(raw);
      if (cfg && typeof cfg.apiBaseUrl === "string" && cfg.apiBaseUrl.trim()) {
        const ok = validateApiBaseUrl(cfg.apiBaseUrl.trim());
        if (ok) return ok;
        // Untrusted plaintext file pointing off-allowlist — ignore it.
      }
    } catch {
      /* no/!invalid config file — fall through to default */
    }
  }
  return DEFAULT_API_BASE_URL;
}

module.exports = {
  HOST,
  BASE_PORT,
  DEFAULT_API_BASE_URL,
  ALLOWED_API_HOSTS,
  resolveApiBaseUrl,
  validateApiBaseUrl,
};
