import { authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

type Ctx = { params: Promise<{ productId: string }> };

/** PUT /me/cart/:productId — set line quantity (0 removes). Auth required. */
export async function PUT(req: Request, { params }: Ctx) {
  const { productId } = await params;
  const body = await req.json().catch(() => null);
  const res = await authedFetch(`/me/cart/${encodeURIComponent(productId)}`, {
    method: "PUT",
    body: JSON.stringify(body),
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not update cart.") },
      { status: res.status },
    );
  }
  if (res.status === 204) return new NextResponse(null, { status: 204 });
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}

/** DELETE /me/cart/:productId — remove a single line. Auth required. */
export async function DELETE(_req: Request, { params }: Ctx) {
  const { productId } = await params;
  const res = await authedFetch(`/me/cart/${encodeURIComponent(productId)}`, {
    method: "DELETE",
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not remove item.") },
      { status: res.status },
    );
  }
  return new NextResponse(null, { status: 204 });
}
