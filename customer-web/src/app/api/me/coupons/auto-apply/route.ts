import { proxyAuthed } from "@/server/bff";

export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  return proxyAuthed(
    "/me/coupons/auto-apply",
    { method: "POST", body: JSON.stringify(body) },
    "Could not auto-apply coupon.",
  );
}
