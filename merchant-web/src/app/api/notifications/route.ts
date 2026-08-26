import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/notifications", req), req, { fallback: "Could not load notifications." });
}
