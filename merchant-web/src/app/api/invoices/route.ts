import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/invoices", req), req, { fallback: "Could not load invoices." });
}

export function POST(req: Request) {
  return proxy("/invoices", req, { fallback: "Could not create the invoice." });
}
