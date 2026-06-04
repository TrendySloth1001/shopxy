import { NextResponse } from "next/server";
import { deleteAccountSchema, updateProfileSchema } from "@/features/auth/schema";
import { authUserSchema } from "@/features/auth/types";
import {
  authedFetch,
  clearSessionCookies,
  extractError,
  getCurrentUser,
} from "@/server/auth/session";

// GET /api/auth/me — the single source of truth for "who is signed in".
// Refreshes the token pair transparently on a 401; returns 401 when there is
// no valid, role-appropriate session.
export async function GET() {
  const user = await getCurrentUser();
  if (!user) {
    return NextResponse.json({ user: null }, { status: 401 });
  }
  return NextResponse.json({ user });
}

// Fields an empty input should CLEAR (→ null). `name` is never cleared.
const CLEARABLE = ["phoneNumber"] as const;

// PATCH /api/auth/me — update the customer profile.
export async function PATCH(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = updateProfileSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0]?.message ?? "Invalid input." },
      { status: 400 },
    );
  }

  const body: Record<string, unknown> = { ...parsed.data };
  for (const key of CLEARABLE) {
    if (key in body && body[key] === "") body[key] = null;
  }

  const res = await authedFetch("/auth/me", {
    method: "PATCH",
    body: JSON.stringify(body),
  });
  if (!res) return NextResponse.json({ user: null }, { status: 401 });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not save your changes.") },
      { status: 400 },
    );
  }

  const enriched = await getCurrentUser();
  if (enriched) return NextResponse.json({ user: enriched });
  const fallback = authUserSchema.safeParse(await res.json());
  return NextResponse.json({ user: fallback.success ? fallback.data : null });
}

// DELETE /api/auth/me — DPDP erasure. Customer accounts cascade freely; a wrong
// password returns 400.
export async function DELETE(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = deleteAccountSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Enter your password to confirm." },
      { status: 400 },
    );
  }

  const res = await authedFetch("/auth/me", {
    method: "DELETE",
    body: JSON.stringify(parsed.data),
  });
  if (!res) return NextResponse.json({ error: "Session expired." }, { status: 401 });

  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as { error?: string };
    if (body.error === "invalid_password") {
      return NextResponse.json(
        { error: "That password is incorrect." },
        { status: 400 },
      );
    }
    return NextResponse.json(
      { error: "Could not delete your account." },
      { status: 400 },
    );
  }

  await clearSessionCookies();
  return NextResponse.json({ ok: true });
}
