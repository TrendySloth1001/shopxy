import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/cashier/authorize", req, { fallback: "Could not authorise." });
}
