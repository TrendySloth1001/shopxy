import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";

// POST /api/orders/:id/reject — decline the order (optional note). Backend
// answers 204 on success.
export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const body = await req.json().catch(() => ({}));
  const res = await authedFetch(`/orders/${encodeURIComponent(id)}/reject`, {
    method: "POST",
    body: JSON.stringify(body && typeof body === "object" ? body : {}),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok && res.status !== 204) {
    return NextResponse.json(
      { error: await extractError(res, "Could not decline the order.") },
      { status: res.status },
    );
  }
  return new NextResponse(null, { status: 204 });
}
