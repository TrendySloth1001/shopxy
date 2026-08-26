import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/notifications/read-all", req, { fallback: "Could not mark all read." });
}
