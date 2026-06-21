"use strict";

const http = require("node:http");
const net = require("node:net");
const path = require("node:path");
const fs = require("node:fs");
const { spawn } = require("node:child_process");
const { HOST, BASE_PORT, resolveApiBaseUrl } = require("./config");

// merchant-desktop/lib -> repo root -> merchant-web
const MERCHANT_WEB = path.resolve(__dirname, "..", "..", "merchant-web");

/** Resolve a free port starting at BASE_PORT (keeps the cookie origin stable). */
function findPort(start) {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once("error", () => {
      if (start - BASE_PORT > 20) return reject(new Error("no free port near 31010"));
      resolve(findPort(start + 1));
    });
    srv.once("listening", () => {
      srv.close(() => resolve(start));
    });
    srv.listen(start, HOST);
  });
}

/** Poll until the local server answers (any HTTP status counts as "up"). */
function waitForServer(url, timeoutMs = 40000) {
  const deadline = Date.now() + timeoutMs;
  return new Promise((resolve, reject) => {
    const tick = () => {
      const req = http.get(url, (res) => {
        res.resume();
        resolve();
      });
      req.on("error", () => {
        if (Date.now() > deadline) reject(new Error("Next.js server did not start in time"));
        else setTimeout(tick, 400);
      });
    };
    tick();
  });
}

/** Path to the local Next CLI in merchant-web (dev mode). */
function nextBin() {
  const bin = process.platform === "win32" ? "next.cmd" : "next";
  return path.join(MERCHANT_WEB, "node_modules", ".bin", bin);
}

/**
 * Boot the merchant-web Next.js server locally and return { url, stop }.
 *  - dev  (SHOPXY_DESKTOP_DEV=1): runs `next dev` against merchant-web source.
 *  - prod (default): runs the bundled standalone `server.js` produced by
 *    `DESKTOP_BUILD=1 next build` (see scripts/stage-web.js + README).
 * API_BASE_URL is injected at runtime so the same shell can target any backend.
 */
async function startServer({ userDataDir, isPackaged, resourcesPath } = {}) {
  // Packaged builds never run `next dev` — they always serve the bundled
  // standalone server from inside the app's resources.
  const isDev = !isPackaged && process.env.SHOPXY_DESKTOP_DEV === "1";
  const port = await findPort(BASE_PORT);
  const url = `http://${HOST}:${port}`;
  const apiBaseUrl = resolveApiBaseUrl(userDataDir);

  const env = {
    ...process.env,
    PORT: String(port),
    HOSTNAME: HOST,
    API_BASE_URL: apiBaseUrl,
  };

  let child;
  if (isDev) {
    env.NODE_ENV = "development";
    child = spawn(nextBin(), ["dev", "-p", String(port), "-H", HOST], {
      cwd: MERCHANT_WEB,
      env,
      stdio: "inherit",
    });
  } else {
    // Packaged: the staged standalone bundle lives at <resources>/web.
    // Unpackaged `npm start`: the repo's .next-build/standalone.
    const standaloneDir = isPackaged
      ? path.join(resourcesPath, "web")
      : path.join(MERCHANT_WEB, ".next-build", "standalone");
    const serverJs = path.join(standaloneDir, "server.js");
    if (!fs.existsSync(serverJs)) {
      throw new Error(
        `Standalone build not found at ${serverJs}.\n` +
          `Run \`npm run build:web && npm run stage:web\` first (or use \`npm run dev\`).`,
      );
    }
    env.NODE_ENV = "production";
    // Run the bundled Next server with Electron's own Node binary.
    env.ELECTRON_RUN_AS_NODE = "1";
    child = spawn(process.execPath, [serverJs], {
      cwd: path.dirname(serverJs),
      env,
      stdio: "inherit",
    });
  }

  child.on("exit", (code) => {
    if (code && code !== 0) console.error(`[merchant-web] server exited with code ${code}`);
  });

  await waitForServer(url);
  return {
    url,
    apiBaseUrl,
    stop: () => {
      try {
        child.kill();
      } catch {
        /* already gone */
      }
    },
  };
}

module.exports = { startServer, MERCHANT_WEB };
