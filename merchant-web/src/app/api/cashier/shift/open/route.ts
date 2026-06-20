import { proxy } from "@/server/proxy";

// POST /api/cashier/shift/open → open a till shift with an opening float.
export function POST(req: Request) {
  return proxy("/me/cashier/shift/open", req, { fallback: "Could not open the shift." });
}
