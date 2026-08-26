import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/cashier/shift/open", req, { fallback: "Could not open the shift." });
}
