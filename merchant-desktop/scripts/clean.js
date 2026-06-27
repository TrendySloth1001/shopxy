"use strict";

/**
 * Remove stale build artifacts before packaging so a new binary never ships a
 * previous build's standalone bundle / orphaned routes. Runs as the first step
 * of `prepack:web` (clean -> build:web -> stage:web).
 *
 * Scope (per the "web bundle + this arch" decision): the merchant-web build dir
 * and the current arch's mac dist output. Other-arch installers (win/linux/x64)
 * are left intact so they don't need rebuilding.
 *
 * Usage from merchant-desktop: `npm run clean`.
 */
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..", "..");
const MERCHANT_WEB = path.join(ROOT, "merchant-web");
const DIST = path.join(ROOT, "dist");

// Stale sources of the bug: the Next build dir (may retain deleted routes) and
// the unpacked mac app + its dmg/zip (electron-builder reuses the .app dir).
const TARGETS = [
  path.join(MERCHANT_WEB, ".next-build"),
  path.join(DIST, "mac-arm64"),
  path.join(DIST, "ShopXY Merchant-0.1.1-arm64.dmg"),
  path.join(DIST, "ShopXY Merchant-0.1.1-arm64.dmg.blockmap"),
  path.join(DIST, "ShopXY Merchant-0.1.1-arm64-mac.zip"),
  path.join(DIST, "ShopXY Merchant-0.1.1-arm64-mac.zip.blockmap"),
];

console.log("Cleaning stale build artifacts…");
for (const target of TARGETS) {
  if (fs.existsSync(target)) {
    fs.rmSync(target, { recursive: true, force: true });
    console.log(`  ✓ removed ${path.relative(ROOT, target)}`);
  }
}
console.log("Done.");
