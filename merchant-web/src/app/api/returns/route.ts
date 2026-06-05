import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/orders/returns", req), req, { fallback: "Could not load returns." });
}
