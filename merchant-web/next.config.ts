import type { NextConfig } from "next";
import { readFileSync } from "node:fs";
import createNextIntlPlugin from "next-intl/plugin";

const { version } = JSON.parse(readFileSync("./package.json", "utf8")) as { version: string };

const isStandaloneBuild = process.env.DESKTOP_BUILD === "1" || process.env.DOCKER_BUILD === "1";

const SECURITY_HEADERS = [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=()",
  },
  {
    key: "Content-Security-Policy",
    value: "frame-ancestors 'none'; object-src 'none'; base-uri 'self'",
  },
];

const nextConfig: NextConfig = {
  reactCompiler: true,
  experimental: {
    optimizePackageImports: [
      "@/shared/icons",
      "@hugeicons/react",
      "@hugeicons/core-free-icons",
    ],
  },
  env: { NEXT_PUBLIC_APP_VERSION: version },
  distDir: process.env.NEXT_DIST_DIR ?? ".next",
  async headers() {
    return [{ source: "/(.*)", headers: SECURITY_HEADERS }];
  },
  ...(isStandaloneBuild
    ? {
        output: "standalone" as const,
        images: { unoptimized: true },
        typescript: { ignoreBuildErrors: true },
        eslint: { ignoreDuringBuilds: true },
      }
    : {}),
};

const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

export default withNextIntl(nextConfig);
