import { authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

/** GET /me/cart — fetch the caller's cart. Auth required. */
export async function GET() {
  const res = await authedFetch("/me/cart");
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load cart.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}

/** DELETE /me/cart — clear the entire cart. Auth required. */
export async function DELETE() {
  const res = await authedFetch("/me/cart", { method: "DELETE" });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not clear cart.") },
      { status: res.status },
    );
  }
  return new NextResponse(null, { status: 204 });
}
