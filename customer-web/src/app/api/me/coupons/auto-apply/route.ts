import { proxyAuthed } from "@/server/bff";

/** POST /me/coupons/auto-apply — best PUBLIC coupon for the current cart. Auth required. */
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  return proxyAuthed(
    "/me/coupons/auto-apply",
    { method: "POST", body: JSON.stringify(body) },
    "Could not auto-apply coupon.",
  );
}
