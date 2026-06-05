import { proxy, withQuery } from "@/server/proxy";

// GET /api/parties · POST /api/parties → /parties
export function GET(req: Request) {
  return proxy(withQuery("/parties", req), req, { fallback: "Could not load customers." });
}

export function POST(req: Request) {
  return proxy("/parties", req, { fallback: "Could not create the customer." });
}
