import { proxy, withQuery } from "@/server/proxy";

// GET /api/promotions · POST /api/promotions
export function GET(req: Request) {
  return proxy(withQuery("/me/promotions", req), req, { fallback: "Could not load promotions." });
}

export function POST(req: Request) {
  return proxy("/me/promotions", req, { fallback: "Could not create the promotion." });
}
