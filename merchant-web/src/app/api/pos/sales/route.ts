import { proxy } from "@/server/proxy";

// GET (list open/held sales) · POST (open a new sale) → backend /me/pos/sales
export function GET(req: Request) {
  return proxy("/me/pos/sales", req, { fallback: "Could not load sales." });
}
export function POST(req: Request) {
  return proxy("/me/pos/sales", req, { fallback: "Could not open a sale." });
}
