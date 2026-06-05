import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/me/analytics/customers", req), req, {
    fallback: "Could not load customers.",
  });
}
