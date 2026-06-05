import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/reports/sales", req), req, { fallback: "Could not load the sales report." });
}
