import { backendFetch, extractError } from "@/server/auth/session";
import { NextResponse } from "next/server";

/** POST /search — full-text / hybrid product search. Auth optional. */
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  const res = await backendFetch("/search", {
    method: "POST",
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Search failed.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}
