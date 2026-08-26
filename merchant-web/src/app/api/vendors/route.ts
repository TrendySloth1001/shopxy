import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/vendors", req), req, { fallback: "Could not load vendors." });
}

export function POST(req: Request) {
  return proxy("/vendors", req, { fallback: "Could not create the vendor." });
}
