import { NextResponse } from "next/server";
import { proxy, withQuery } from "@/server/proxy";

// GET /api/payouts — Razorpay-Route linked-account status. A merchant who
// hasn't started onboarding is a normal state, not an error, so collapse the
// backend's 404 into a 200/null. That keeps it out of the browser console as a
// failed request; the client maps a null body to "not started".
export async function GET(req: Request) {
  const res = await proxy(withQuery("/linked-account", req), undefined, {
    fallback: "Could not load payout status.",
  });
  if (res.status === 404) return NextResponse.json(null, { status: 200 });
  return res;
}
