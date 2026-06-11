import { authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

type Ctx = { params: Promise<{ id: string }> };

/** PATCH /me/addresses/:id — update an address. Auth required. */
export async function PATCH(req: Request, { params }: Ctx) {
  const { id } = await params;
  const body = await req.json().catch(() => null);
  const res = await authedFetch(`/me/addresses/${encodeURIComponent(id)}`, {
    method: "PATCH",
    body: JSON.stringify(body),
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not update address.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}

/** DELETE /me/addresses/:id — remove an address. Auth required. */
export async function DELETE(_req: Request, { params }: Ctx) {
  const { id } = await params;
  const res = await authedFetch(`/me/addresses/${encodeURIComponent(id)}`, {
    method: "DELETE",
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not delete address.") },
      { status: res.status },
    );
  }
  return new NextResponse(null, { status: 204 });
}
