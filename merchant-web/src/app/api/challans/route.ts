import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/challans", req), req, { fallback: "Could not load challans." });
}

export function POST(req: Request) {
  return proxy("/challans", req, { fallback: "Could not create the challan." });
}
