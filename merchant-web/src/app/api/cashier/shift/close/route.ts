import { proxy } from "@/server/proxy";

// POST /api/cashier/shift/close → close the shift with the counted cash.
export function POST(req: Request) {
  return proxy("/me/cashier/shift/close", req, { fallback: "Could not close the shift." });
}
