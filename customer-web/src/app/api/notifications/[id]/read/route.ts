import { NextResponse } from "next/server";
import { authedFetch, extractError } from "@/server/auth/session";

type Ctx = { params: Promise<{ id: string }> };

/** Mark a single notification read. */
export async function POST(_req: Request, { params }: Ctx) {
  const { id } = await params;
  const res = await authedFetch(`/notifications/${encodeURIComponent(id)}/read`, { method: "POST" });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok && res.status !== 204) {
    return NextResponse.json(
      { error: await extractError(res, "Could not mark it read.") },
      { status: res.status },
    );
  }
  return new NextResponse(null, { status: 204 });
}
