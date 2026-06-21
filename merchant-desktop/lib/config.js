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

function resolveApiBaseUrl(userDataDir) {
  const fromEnv = process.env.SHOPXY_API_BASE_URL;
  if (fromEnv && fromEnv.trim()) return fromEnv.trim().replace(/\/+$/, "");

  if (userDataDir) {
    try {
      const raw = fs.readFileSync(path.join(userDataDir, "config.json"), "utf8");
      const cfg = JSON.parse(raw);
      if (cfg && typeof cfg.apiBaseUrl === "string" && cfg.apiBaseUrl.trim()) {
        return cfg.apiBaseUrl.trim().replace(/\/+$/, "");
      }
    } catch {
      /* no/!invalid config file — fall through to default */
    }
  }
  return DEFAULT_API_BASE_URL;
}

module.exports = { HOST, BASE_PORT, DEFAULT_API_BASE_URL, resolveApiBaseUrl };
