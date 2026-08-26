import { NextResponse } from "next/server";
import { backendFetch, extractError } from "@/server/auth/session";

export async function GET() {
  const res = await backendFetch("/home/feed");
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not load the home feed.") },
      { status: res.status },
    );
  }
  return NextResponse.json(await res.json().catch(() => null), { status: 200 });
}
