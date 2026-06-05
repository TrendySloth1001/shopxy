import { proxy, withQuery } from "@/server/proxy";

/** Record a stock movement (STOCK_IN / STOCK_OUT) → backend creates a draft invoice. */
export function POST(req: Request) {
  return proxy("/stock", req, { fallback: "Could not record the stock movement." });
}

/** Stock ledger (transactions), optionally filtered by product/type. */
export function GET(req: Request) {
  return proxy(withQuery("/stock", req), req, { fallback: "Could not load stock movements." });
}
