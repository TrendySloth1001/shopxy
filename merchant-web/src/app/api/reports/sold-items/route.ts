import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/reports/sold-items", req), req, {
    fallback: "Could not load sold products.",
  });
}
