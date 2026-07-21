import type { NextConfig } from "next";

// Conservative security-header set applied to every response. The CSP is kept
// intentionally minimal — `frame-ancestors`/`object-src`/`base-uri` are safe
// to pin hard, while a tight `script-src` would need a nonce for Next's runtime
// inline bootstrap, so that is deferred (see TODO) rather than risk breaking the
// app. Headers mirror merchant-web — keep the two in sync.
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
  // Icons funnel through the `@/shared/icons` barrel (which re-exports the whole
  // lucide set). Register it here so Next rewrites barrel imports to direct
  // member imports — keeping the icon set fully tree-shaken despite the barrel.
  experimental: { optimizePackageImports: ["@/shared/icons"] },
  // `next build` writes to a separate dir (set by the build/start scripts) so a
  // production build never clobbers the live `next dev` Turbopack cache in
  // `.next/` — that overlap corrupts the dev cache (missing .sst files). Dev
  // stays on the default `.next`; build/start use `.next-build`.
  distDir: process.env.NEXT_DIST_DIR ?? ".next",
  images: {
    // Product/banner imagery is merchant-supplied and can live on any https
    // host (seed data uses Unsplash). We do NOT open the Next image optimizer
    // to arbitrary remote hosts — `remotePatterns: hostname:"**"` is a
    // server-side SSRF primitive (the optimizer would fetch any attacker URL,
    // e.g. cloud metadata). Instead the optimizer is disabled and images are
    // served as-is: backend-relative images go through the same-origin
    // `/api/media` proxy, and absolute merchant URLs load directly in the
    // browser. Mirrors merchant-web's desktop config.
    unoptimized: true,
  },
  async headers() {
    return [{ source: "/(.*)", headers: SECURITY_HEADERS }];
  },
};

export default nextConfig;
