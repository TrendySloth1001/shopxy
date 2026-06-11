import { authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

/** GET /me/orders — paginated order list. Auth required. */
export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  const res = await authedFetch(`/me/orders${qs ? `?${qs}` : ""}`);
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load orders.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}

/** POST /me/orders — place a new order. Auth required. */
export async function POST(req: Request) {
  const idempotencyKey =
    req.headers.get("Idempotency-Key") ??
    req.headers.get("X-Idempotency-Key") ??
    null;
  const body = await req.json().catch(() => null);
  const headers: Record<string, string> = {};
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;

  const res = await authedFetch("/me/orders", {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    // Pass through the full body so callers can read structured fields like `details`
    // (e.g. PRICE_DRIFT returns { error, details: [{ productId, name, oldPrice, newPrice }] })
    const errBody = await res.json().catch(() => null) as Record<string, unknown> | null;
    return NextResponse.json(errBody ?? { error: "Could not place order." }, { status: res.status });
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}
