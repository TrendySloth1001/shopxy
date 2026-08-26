import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/linked-account/connect", req, { fallback: "Could not verify that account." });
}
