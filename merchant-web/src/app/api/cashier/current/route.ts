import { proxy } from "@/server/proxy";

// GET /api/cashier/current → the caller's open shift + live report (or nulls).
export function GET(req: Request) {
  return proxy("/me/cashier/current", req, { fallback: "Could not load the till." });
}
