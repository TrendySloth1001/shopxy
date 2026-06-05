import { proxy, withQuery } from "@/server/proxy";

// GET /api/spotlight · POST /api/spotlight (→ backend POST /me/brand-spotlight/request)
export function GET(req: Request) {
  return proxy(withQuery("/me/brand-spotlight", req), req, {
    fallback: "Could not load spotlight requests.",
  });
}

export function POST(req: Request) {
  return proxy("/me/brand-spotlight/request", req, {
    fallback: "Could not submit the request.",
  });
}
