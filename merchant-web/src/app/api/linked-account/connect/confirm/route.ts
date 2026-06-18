import { proxy } from "@/server/proxy";

// POST /api/linked-account/connect/confirm — store the verified account.
export function POST(req: Request) {
  return proxy("/linked-account/connect/confirm", req, { fallback: "Could not link that account." });
}
