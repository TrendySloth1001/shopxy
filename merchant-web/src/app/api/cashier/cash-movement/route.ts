import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/cashier/cash-movement", req, { fallback: "Could not record the cash movement." });
}
