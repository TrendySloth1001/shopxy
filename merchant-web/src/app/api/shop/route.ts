import { proxy } from "@/server/proxy";

export function GET() {
  return proxy("/me/shop", undefined, { fallback: "Could not load your shop." });
}

export function PUT(req: Request) {
  return proxy("/me/shop", req, { method: "PUT", fallback: "Could not save your shop." });
}
