import { proxy, withQuery } from "@/server/proxy";

/** Suppliers for the stock-in picker: structured vendors + free-text history. */
export function GET(req: Request) {
  return proxy(withQuery("/stock/suppliers", req), req, { fallback: "Could not load suppliers." });
}
