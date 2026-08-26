import { proxy } from "@/server/proxy";

export function GET(req: Request) {
  return proxy("/me/cashier/current", req, { fallback: "Could not load the till." });
}
