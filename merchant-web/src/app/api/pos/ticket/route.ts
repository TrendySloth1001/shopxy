import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/pos/ticket", req, { fallback: "Could not start the live cart." });
}
