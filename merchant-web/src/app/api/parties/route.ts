import { proxy, withQuery } from "@/server/proxy";

// GET /api/parties · POST /api/parties → /me/parties
export function GET(req: Request) {
  return proxy(withQuery("/me/parties", req), req, { fallback: "Could not load customers." });
}

export function POST(req: Request) {
  return proxy("/me/parties", req, { fallback: "Could not create the customer." });
}
