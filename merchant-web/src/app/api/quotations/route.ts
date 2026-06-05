import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/quotations", req), req, { fallback: "Could not load quotations." });
}

export function POST(req: Request) {
  return proxy("/quotations", req, { fallback: "Could not send the quotation." });
}
