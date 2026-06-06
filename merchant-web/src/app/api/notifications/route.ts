import { proxy, withQuery } from "@/server/proxy";

/** List the signed-in user's notifications (paginated, with unread count). */
export function GET(req: Request) {
  return proxy(withQuery("/notifications", req), req, { fallback: "Could not load notifications." });
}
