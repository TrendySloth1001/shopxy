import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";
import { reviewSummarySchema } from "@/features/reviews/schema";

// GET /api/products/:id/reviews/summary — proxies the public backend summary.
export async function GET(
  _req: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const res = await authedFetch(
    `/products/${encodeURIComponent(id)}/reviews/summary`,
  );
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load reviews.") },
      { status: res.status },
    );
  }
  const parsed = reviewSummarySchema.safeParse(await res.json());
  if (!parsed.success) {
    return NextResponse.json({ error: "Unexpected review data." }, { status: 502 });
  }
  return NextResponse.json(parsed.data);
}
