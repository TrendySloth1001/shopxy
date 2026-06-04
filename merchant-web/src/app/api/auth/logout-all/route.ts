import { NextResponse } from "next/server";
import { authedFetch, clearSessionCookies } from "@/server/auth/session";

// POST /api/auth/logout-all — revoke every session (this device included). The
// backend deletes all refresh tokens and bumps tokensValidFrom, so we clear
// the local cookies too and the client returns to sign-in.
export async function POST() {
  const res = await authedFetch("/auth/logout-all", { method: "POST" });
  await clearSessionCookies();
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  return new NextResponse(null, { status: 204 });
}
