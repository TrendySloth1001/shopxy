"use strict";

const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..", "..");
const MERCHANT_WEB = path.join(ROOT, "merchant-web");
const DIST = path.join(ROOT, "dist");

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
