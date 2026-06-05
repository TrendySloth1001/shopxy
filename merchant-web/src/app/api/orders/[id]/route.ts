import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";
import { orderDetailSchema } from "@/features/orders/schema";

// GET /api/orders/:id — order detail.
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const res = await authedFetch(`/orders/${encodeURIComponent(id)}`);
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load the order.") },
      { status: res.status },
    );
  }
  const parsed = orderDetailSchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected order data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}
