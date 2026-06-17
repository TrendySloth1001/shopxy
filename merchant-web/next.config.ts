import type { NextConfig } from "next";
import { readFileSync } from "node:fs";

// Surface the package version as a build-time constant so the Settings → About
// "App version" row reflects the real release instead of a hard-coded string.
const { version } = JSON.parse(readFileSync("./package.json", "utf8")) as { version: string };

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  env: { NEXT_PUBLIC_APP_VERSION: version },
  // `next build` writes to a separate dir (set by the build/start scripts) so a
  // production build never clobbers the live `next dev` Turbopack cache in
  // `.next/` — that overlap corrupts the dev cache (missing .sst files). Dev
  // stays on the default `.next`; build/start use `.next-build`.
  distDir: process.env.NEXT_DIST_DIR ?? ".next",
};

export default nextConfig;
