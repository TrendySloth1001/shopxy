import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/me/banners", req), req, { fallback: "Could not load banners." });
}

export function POST(req: Request) {
  return proxy("/me/banners", req, { fallback: "Could not create the banner." });
}
