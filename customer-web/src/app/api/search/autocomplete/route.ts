import { backendFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

export async function GET(req: Request) {
  const qs = new URL(req.url).searchParams.toString();
  const res = await backendFetch(`/search/autocomplete${qs ? `?${qs}` : ""}`);
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load suggestions.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}
