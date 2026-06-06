import { proxy, withQuery } from "@/server/proxy";

// GET /api/invitations/incoming → /invitations/incoming (invites sent to me)
export function GET(req: Request) {
  return proxy(withQuery("/invitations/incoming", req), req, {
    fallback: "Could not load invitations.",
  });
}
