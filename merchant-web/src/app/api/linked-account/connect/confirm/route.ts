import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/linked-account/connect/confirm", req, { fallback: "Could not link that account." });
}
