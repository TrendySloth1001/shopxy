import { proxy, withQuery } from "@/server/proxy";

// GET /api/caution-requests → /caution-requests (shop-wide pending inbox)
export function GET(req: Request) {
  return proxy(withQuery("/caution-requests", req), req, {
    fallback: "Could not load caution requests.",
  });
}
