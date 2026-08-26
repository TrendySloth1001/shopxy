import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/stock/suppliers", req), req, { fallback: "Could not load suppliers." });
}
