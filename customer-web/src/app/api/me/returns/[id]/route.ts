import { authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

type Ctx = { params: Promise<{ id: string }> };

/** GET /me/returns/:id — return detail. Auth required. */
export async function GET(_req: Request, { params }: Ctx) {
  const { id } = await params;
  const res = await authedFetch(`/me/returns/${encodeURIComponent(id)}`);
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load return.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}
