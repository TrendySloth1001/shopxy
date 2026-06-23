import { proxyAuthedPassthrough } from "@/server/bff";

/**
 * POST /me/coupons/validate — check a coupon code. Auth required.
 *
 * Forwards the backend response verbatim: a successful preview is a 200 with
 * `{ ok: true, coupon }`, while a rejected coupon is a 400 with
 * `{ ok: false, code, message }`. The client reads both shapes directly, so we
 * must NOT collapse the 400 into the generic `{ error }` envelope.
 */
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  return proxyAuthedPassthrough("/me/coupons/validate", {
    method: "POST",
    body: JSON.stringify(body),
  });
}
