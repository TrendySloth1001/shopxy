import { NextResponse } from "next/server";
import { authedFetch, clearSessionCookies } from "@/server/auth/session";

export async function POST() {
  const res = await authedFetch("/auth/logout-all", { method: "POST" });
  await clearSessionCookies();
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  return new NextResponse(null, { status: 204 });
}
