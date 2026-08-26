import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/me/cashier/shifts", req), req, { fallback: "Could not load shift history." });
}
