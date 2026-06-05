import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/payments", req), req, { fallback: "Could not load payments." });
}

export function POST(req: Request) {
  return proxy("/payments", req, { fallback: "Could not record the payment." });
}
