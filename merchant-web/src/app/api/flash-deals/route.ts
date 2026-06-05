import { proxy, withQuery } from "@/server/proxy";

// GET /api/flash-deals[?status=] · POST /api/flash-deals
export function GET(req: Request) {
  return proxy(withQuery("/me/flash-deals", req), req, { fallback: "Could not load flash deals." });
}

export function POST(req: Request) {
  return proxy("/me/flash-deals", req, { fallback: "Could not create the flash deal." });
}
