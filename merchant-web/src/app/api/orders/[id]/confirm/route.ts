import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";
import { confirmResultSchema } from "@/features/orders/schema";

export async function POST(
  req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const body = await req.json().catch(() => ({}));
  const res = await authedFetch(`/orders/${encodeURIComponent(id)}/confirm`, {
    method: "POST",
    body: JSON.stringify(body && typeof body === "object" ? body : {}),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });

  if (!res.ok) {
    const raw = await res.clone().json().catch(() => null);
    if (raw && typeof raw === "object" && "error" in raw) {
      return NextResponse.json(raw, { status: res.status });
    }
    return NextResponse.json(
      { error: await extractError(res, "Could not confirm the order.") },
      { status: res.status },
    );
  }

  const parsed = confirmResultSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected confirm response." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}
