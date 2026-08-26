import { proxy } from "@/server/proxy";

export function GET(req: Request) {
  return proxy("/me/coupons-admin", req, { fallback: "Could not load coupons." });
}

export function POST(req: Request) {
  return proxy("/me/coupons-admin", req, { fallback: "Could not create the coupon." });
}
