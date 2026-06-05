import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/stock-adjustments", req), req, { fallback: "Could not load adjustments." });
}

export function POST(req: Request) {
  return proxy("/stock-adjustments", req, { fallback: "Could not post the adjustment." });
}
