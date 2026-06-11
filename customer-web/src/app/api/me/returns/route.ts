import { authedFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

/** GET /me/returns — paginated return requests. Auth required. */
export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  const res = await authedFetch(`/me/returns${qs ? `?${qs}` : ""}`);
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load returns.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}

/** POST /me/returns — create a return request. Auth required. */
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  const res = await authedFetch("/me/returns", {
    method: "POST",
    body: JSON.stringify(body),
  });
  if (!res)
    return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not submit return request.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: res.status });
}
