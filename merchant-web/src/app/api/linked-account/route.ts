import { proxy } from "@/server/proxy";

// POST /api/linked-account — start Razorpay Route KYC onboarding for the shop.
// PAN/bank are forwarded to the provider and never stored by us.
export function POST(req: Request) {
  return proxy("/linked-account", req, { fallback: "Could not start onboarding." });
}
