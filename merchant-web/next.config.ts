import type { NextConfig } from "next";
import { readFileSync } from "node:fs";
import createNextIntlPlugin from "next-intl/plugin";

// Surface the package version as a build-time constant so the Settings → About
// "App version" row reflects the real release instead of a hard-coded string.
const { version } = JSON.parse(readFileSync("./package.json", "utf8")) as { version: string };

// Desktop (Electron) packaging: `DESKTOP_BUILD=1 next build` emits a
// self-contained server under `<distDir>/standalone` that the Electron shell
// boots locally, and skips the built-in image optimizer (which would pull in
// the native `sharp` binary) — images already proxy through `/api/*`, so the
// optimizer isn't needed. Gated so the normal web deploy is unaffected.
// Docker packaging (`DOCKER_BUILD=1`, see Dockerfile) wants the same
// self-contained output for the same reason — a portable image that doesn't
// need `sharp` compiled for the container's platform.
const isStandaloneBuild = process.env.DESKTOP_BUILD === "1" || process.env.DOCKER_BUILD === "1";

// Conservative security-header set applied to every response. The CSP is kept
// intentionally minimal — `frame-ancestors`/`object-src`/`base-uri` are safe
// to pin hard, while a tight `script-src` would need a nonce for Next's runtime
// inline bootstrap, so that is deferred (see TODO) rather than risk breaking the
// app. Headers mirror customer-web — keep the two in sync.
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
    // TODO: tighten script-src with a per-request nonce once the inline theme
    // boot script is nonced; until then only the non-script directives are
    // pinned so the CSP can't break Next's runtime.
    key: "Content-Security-Policy",
    value: "frame-ancestors 'none'; object-src 'none'; base-uri 'self'",
  },
];

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  // Icons funnel through the `@/shared/icons` barrel (Hugeicons wrappers).
  // Register it here so Next rewrites barrel imports to direct member imports —
  // keeping the icon set fully tree-shaken despite the barrel. The underlying
  // Hugeicons packages are also listed: `core-free-icons` is ~90 MB of icon-data
  // exports, so this is a safety net against a stray import pulling the whole set.
  experimental: {
    optimizePackageImports: [
      "@/shared/icons",
      "@hugeicons/react",
      "@hugeicons/core-free-icons",
    ],
  },
  env: { NEXT_PUBLIC_APP_VERSION: version },
  // `next build` writes to a separate dir (set by the build/start scripts) so a
  // production build never clobbers the live `next dev` Turbopack cache in
  // `.next/` — that overlap corrupts the dev cache (missing .sst files). Dev
  // stays on the default `.next`; build/start use `.next-build`.
  distDir: process.env.NEXT_DIST_DIR ?? ".next",
  async headers() {
    return [{ source: "/(.*)", headers: SECURITY_HEADERS }];
  },
  ...(isStandaloneBuild
    ? {
        output: "standalone" as const,
        images: { unoptimized: true },
        // The desktop/Docker standalone bundle is verified separately (tsc +
        // eslint). Skip the in-build re-check, which otherwise chokes on a
        // concurrently running dev server's stale `.next/dev/types` route
        // artifacts (the multi-session hazard). Normal web builds still
        // type-check + lint.
        typescript: { ignoreBuildErrors: true },
        eslint: { ignoreDuringBuilds: true },
      }
    : {}),
};

// Wire next-intl. App Router with NO i18n routing — the active locale comes
// from a cookie, resolved in src/i18n/request.ts (not the URL).
const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

export default withNextIntl(nextConfig);
