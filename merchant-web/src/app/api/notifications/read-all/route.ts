import { proxy } from "@/server/proxy";

/** Mark every notification read for the signed-in user. */
export function POST(req: Request) {
  return proxy("/notifications/read-all", req, { fallback: "Could not mark all read." });
}
