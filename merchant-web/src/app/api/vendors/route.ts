import { proxy, withQuery } from "@/server/proxy";

// GET /api/vendors · POST /api/vendors → /me/vendors
export function GET(req: Request) {
  return proxy(withQuery("/me/vendors", req), req, { fallback: "Could not load vendors." });
}

export function POST(req: Request) {
  return proxy("/me/vendors", req, { fallback: "Could not create the vendor." });
}
