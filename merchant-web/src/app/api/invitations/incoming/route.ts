import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/invitations/incoming", req), req, {
    fallback: "Could not load invitations.",
  });
}
