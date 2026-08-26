import { authedFetch } from "@/server/auth/session";
import { NextResponse } from "next/server";

type Ctx = { params: Promise<{ id: string; childId: string }> };

export async function POST(_req: Request, { params }: Ctx) {
  const { id, childId } = await params;
  const res = await authedFetch(
    `/me/orders/${encodeURIComponent(id)}/shops/${encodeURIComponent(childId)}/cancel`,
    { method: "POST", body: JSON.stringify({}) },
  );
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    const body = await res.json().catch(() => null) as Record<string, unknown> | null;
    return NextResponse.json(body ?? { error: "Could not cancel order." }, { status: res.status });
  }
  return new NextResponse(null, { status: 204 });
}
