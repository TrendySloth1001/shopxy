import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/reports/sold-products", req), req, {
    fallback: "Could not load sold products.",
  });
}
