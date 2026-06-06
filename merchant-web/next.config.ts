import type { NextConfig } from "next";
import { readFileSync } from "node:fs";

// Surface the package version as a build-time constant so the Settings → About
// "App version" row reflects the real release instead of a hard-coded string.
const { version } = JSON.parse(readFileSync("./package.json", "utf8")) as { version: string };

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  env: { NEXT_PUBLIC_APP_VERSION: version },
};

export default nextConfig;
