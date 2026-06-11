import { proxyAuthed } from "@/server/bff";

/** POST /me/coupons/validate — check a coupon code. Auth required. */
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  return proxyAuthed(
    "/me/coupons/validate",
    { method: "POST", body: JSON.stringify(body) },
    "Could not validate coupon.",
  );
}
