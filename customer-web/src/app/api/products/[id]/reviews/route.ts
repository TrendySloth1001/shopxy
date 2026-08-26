import { backendFetch, authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

type Ctx = { params: Promise<{ id: string }> };

export async function GET(req: Request, { params }: Ctx) {
  const { id } = await params;
  const qs = new URL(req.url).searchParams.toString();
  const path = `/products/${encodeURIComponent(id)}/reviews${qs ? `?${qs}` : ""}`;
  const res = await backendFetch(path);
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load reviews.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}

export async function POST(req: Request, { params }: Ctx) {
  const { id } = await params;
  const body = await req.json().catch(() => null);
  const res = await authedFetch(`/products/${encodeURIComponent(id)}/reviews`, {
    method: "POST",
    body: JSON.stringify(body),
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not submit review.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}
