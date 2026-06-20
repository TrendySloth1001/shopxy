import { proxy, withQuery } from "@/server/proxy";

// GET /api/cashier/shifts → shift history (Z-receipt list).
export function GET(req: Request) {
  return proxy(withQuery("/me/cashier/shifts", req), req, { fallback: "Could not load shift history." });
}
