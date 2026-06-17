import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  // `next build` writes to a separate dir (set by the build/start scripts) so a
  // production build never clobbers the live `next dev` Turbopack cache in
  // `.next/` — that overlap corrupts the dev cache (missing .sst files). Dev
  // stays on the default `.next`; build/start use `.next-build`.
  distDir: process.env.NEXT_DIST_DIR ?? ".next",
  images: {
    // Product/banner imagery is merchant-supplied and can live on any https
    // host (seed data uses Unsplash). Backend-relative images go through the
    // same-origin /api/media proxy, which needs no entry here.
    remotePatterns: [{ protocol: "https", hostname: "**" }],
  },
};

export default nextConfig;
