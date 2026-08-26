import { proxy } from "@/server/proxy";

export function GET(req: Request) {
  return proxy("/me/cashier/report", req, { fallback: "Could not load the report." });
}
