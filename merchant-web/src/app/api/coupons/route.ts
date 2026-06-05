import { proxy } from "@/server/proxy";

// GET /api/coupons · POST /api/coupons → /me/coupons-admin
export function GET(req: Request) {
  return proxy("/me/coupons-admin", req, { fallback: "Could not load coupons." });
}

export function POST(req: Request) {
  return proxy("/me/coupons-admin", req, { fallback: "Could not create the coupon." });
}
