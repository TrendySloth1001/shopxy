import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  reactCompiler: true,
  images: {
    // Product/banner imagery is merchant-supplied and can live on any https
    // host (seed data uses Unsplash). Backend-relative images go through the
    // same-origin /api/media proxy, which needs no entry here.
    remotePatterns: [{ protocol: "https", hostname: "**" }],
  },
};

export default nextConfig;
