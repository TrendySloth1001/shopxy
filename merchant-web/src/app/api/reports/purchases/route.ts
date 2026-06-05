import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/reports/purchases", req), req, {
    fallback: "Could not load the purchases report.",
  });
}
