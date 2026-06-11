import { authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

/** GET /me/reviews — cursor-paginated list of the caller's reviews. Auth required. */
export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  const res = await authedFetch(`/me/reviews${qs ? `?${qs}` : ""}`);
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load your reviews.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}
