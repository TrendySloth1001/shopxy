import { proxy, withQuery } from "@/server/proxy";

// GET /api/payouts — Razorpay-Route linked-account status (404 when not started).
export function GET(req: Request) {
  return proxy(withQuery("/linked-account", req), undefined, {
    fallback: "Could not load payout status.",
  });
}
