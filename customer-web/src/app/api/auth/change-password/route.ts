import { NextResponse } from "next/server";
import { changePasswordSchema } from "@/features/auth/schema";
import {
  authedFetch,
  clearSessionCookies,
  extractError,
} from "@/server/auth/session";

// POST /api/auth/change-password — the backend revokes ALL sessions (including
// this one) and bumps tokensValidFrom on success, so we clear the session
// cookies and the client returns to sign-in.
export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = changePasswordSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0]?.message ?? "Invalid input." },
      { status: 400 },
    );
  }

  const res = await authedFetch("/auth/change-password", {
    method: "POST",
    body: JSON.stringify({
      currentPassword: parsed.data.currentPassword,
      newPassword: parsed.data.newPassword,
    }),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not change your password.") },
      { status: 400 },
    );
  }

  await clearSessionCookies();
  return NextResponse.json({ ok: true });
}
