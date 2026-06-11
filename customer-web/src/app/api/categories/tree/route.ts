import { backendFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

/** GET /categories/tree — full category hierarchy. Public. */
export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  const res = await backendFetch(`/categories/tree${qs ? `?${qs}` : ""}`);
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load categories.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}
