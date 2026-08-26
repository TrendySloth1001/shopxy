import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/cashier/return", req, { fallback: "Could not process the return." });
}
