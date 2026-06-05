import { proxy } from "@/server/proxy";

// GET /api/carousels · POST /api/carousels
export function GET(req: Request) {
  return proxy("/me/carousels", req, { fallback: "Could not load carousels." });
}

export function POST(req: Request) {
  return proxy("/me/carousels", req, { fallback: "Could not create the carousel." });
}
