import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/reports/pnl", req), req, { fallback: "Could not load the P&L report." });
}
