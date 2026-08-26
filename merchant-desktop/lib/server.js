"use strict";

const http = require("node:http");
const net = require("node:net");
const path = require("node:path");
const fs = require("node:fs");
const { spawn } = require("node:child_process");
const { HOST, BASE_PORT, resolveApiBaseUrl } = require("./config");

const MERCHANT_WEB = path.resolve(__dirname, "..", "..", "merchant-web");

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

function nextBin() {
  const bin = process.platform === "win32" ? "next.cmd" : "next";
  return path.join(MERCHANT_WEB, "node_modules", ".bin", bin);
}

async function startServer({ userDataDir, isPackaged, resourcesPath } = {}) {
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
      }
    },
  };
}

module.exports = { startServer, MERCHANT_WEB };
