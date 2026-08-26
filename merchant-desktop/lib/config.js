"use strict";

const fs = require("node:fs");
const path = require("node:path");

const HOST = "127.0.0.1";
const BASE_PORT = 31010;

const DEFAULT_API_BASE_URL = "https://qjhcp0ph-3003.inc1.devtunnels.ms";

const ALLOWED_API_HOSTS = ["qjhcp0ph-3003.inc1.devtunnels.ms"];
const LOOPBACK_HOSTS = ["localhost", "127.0.0.1", "[::1]"];

function isDevEnv() {
  return process.env.NODE_ENV !== "production" || process.env.SHOPXY_DESKTOP_DEV === "1";
}

function validateApiBaseUrl(value) {
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    return null;
  }
  if (LOOPBACK_HOSTS.includes(parsed.hostname)) {
    return isDevEnv() ? value.replace(/\/+$/, "") : null;
  }
  if (parsed.protocol !== "https:") return null;
  if (!ALLOWED_API_HOSTS.includes(parsed.hostname)) return null;
  return value.replace(/\/+$/, "");
}

function resolveApiBaseUrl(userDataDir) {
  const fromEnv = process.env.SHOPXY_API_BASE_URL;
  if (fromEnv && fromEnv.trim()) {
    const ok = validateApiBaseUrl(fromEnv.trim());
    if (ok) return ok;
  }

  if (userDataDir) {
    try {
      const raw = fs.readFileSync(path.join(userDataDir, "config.json"), "utf8");
      const cfg = JSON.parse(raw);
      if (cfg && typeof cfg.apiBaseUrl === "string" && cfg.apiBaseUrl.trim()) {
        const ok = validateApiBaseUrl(cfg.apiBaseUrl.trim());
        if (ok) return ok;
      }
    } catch {
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
