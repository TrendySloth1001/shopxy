"use strict";

const fs = require("node:fs");
const path = require("node:path");

const MERCHANT_WEB = path.resolve(__dirname, "..", "..", "merchant-web");
const DIST = path.join(MERCHANT_WEB, ".next-build");
const STANDALONE = path.join(DIST, "standalone");

function copyDir(src, dest, label) {
  if (!fs.existsSync(src)) {
    console.error(`  ✗ missing ${label}: ${src}`);
    process.exitCode = 1;
    return;
  }
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.cpSync(src, dest, { recursive: true });
  console.log(`  ✓ ${label} → ${path.relative(MERCHANT_WEB, dest)}`);
}

if (!fs.existsSync(path.join(STANDALONE, "server.js"))) {
  console.error(
    `No standalone build at ${STANDALONE}.\n` +
      `Run \`npm run build:web\` (DESKTOP_BUILD=1 next build) first.`,
  );
  process.exit(1);
}

console.log("Staging static assets into the standalone server…");
copyDir(path.join(DIST, "static"), path.join(STANDALONE, ".next-build", "static"), "static");
copyDir(path.join(MERCHANT_WEB, "public"), path.join(STANDALONE, "public"), "public");
console.log("Done.");
