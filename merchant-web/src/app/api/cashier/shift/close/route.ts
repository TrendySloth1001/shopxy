import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/cashier/shift/close", req, { fallback: "Could not close the shift." });
}
