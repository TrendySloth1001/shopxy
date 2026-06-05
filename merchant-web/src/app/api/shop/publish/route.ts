import { proxy } from "@/server/proxy";

export function POST(req: Request) {
  return proxy("/me/shop/publish", req, { fallback: "Could not update publish state." });
}
