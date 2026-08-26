import { proxy, withQuery } from "@/server/proxy";

export function GET(req: Request) {
  return proxy(withQuery("/invitations/outgoing", req), req, {
    fallback: "Could not load invitations.",
  });
}

export function POST(req: Request) {
  return proxy("/invitations", req, { fallback: "Could not send the invitation." });
}
