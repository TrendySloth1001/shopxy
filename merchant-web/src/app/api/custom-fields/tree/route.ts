import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/custom-fields/tree", req), undefined, {
    fallback: "Could not load custom fields.",
  });
}
