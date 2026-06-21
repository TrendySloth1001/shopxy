import type { NextConfig } from "next";
import { readFileSync } from "node:fs";

// Surface the package version as a build-time constant so the Settings → About
// "App version" row reflects the real release instead of a hard-coded string.
const { version } = JSON.parse(readFileSync("./package.json", "utf8")) as { version: string };

// Desktop (Electron) packaging: `DESKTOP_BUILD=1 next build` emits a
// self-contained server under `<distDir>/standalone` that the Electron shell
// boots locally, and skips the built-in image optimizer (which would pull in
// the native `sharp` binary) — images already proxy through `/api/*`, so the
// optimizer isn't needed. Gated so the normal web deploy is unaffected.
const isDesktopBuild = process.env.DESKTOP_BUILD === "1";

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  env: { NEXT_PUBLIC_APP_VERSION: version },
  // `next build` writes to a separate dir (set by the build/start scripts) so a
  // production build never clobbers the live `next dev` Turbopack cache in
  // `.next/` — that overlap corrupts the dev cache (missing .sst files). Dev
  // stays on the default `.next`; build/start use `.next-build`.
  distDir: process.env.NEXT_DIST_DIR ?? ".next",
  ...(isDesktopBuild
    ? { output: "standalone" as const, images: { unoptimized: true } }
    : {}),
};

export default nextConfig;
