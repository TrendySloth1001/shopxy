import { proxy } from "@/server/proxy";

// POST /api/cashier/cash-movement → record a PAY_IN / PAY_OUT / DROP.
export function POST(req: Request) {
  return proxy("/me/cashier/cash-movement", req, { fallback: "Could not record the cash movement." });
}
