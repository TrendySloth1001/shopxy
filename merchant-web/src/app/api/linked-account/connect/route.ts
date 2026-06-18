import { proxy } from "@/server/proxy";

// POST /api/linked-account/connect — verify an existing acc_XXXX (fetch + show).
export function POST(req: Request) {
  return proxy("/linked-account/connect", req, { fallback: "Could not verify that account." });
}
