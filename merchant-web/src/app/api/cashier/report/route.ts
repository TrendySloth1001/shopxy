import { proxy } from "@/server/proxy";

// GET /api/cashier/report → live X-report for the open shift.
export function GET(req: Request) {
  return proxy("/me/cashier/report", req, { fallback: "Could not load the report." });
}
