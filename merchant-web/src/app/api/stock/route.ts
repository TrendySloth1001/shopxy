import { proxy, withQuery } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/stock", req, { fallback: "Could not record the stock movement." });
}

export function GET(req: Request) {
  return proxy(withQuery("/stock", req), req, { fallback: "Could not load stock movements." });
}
