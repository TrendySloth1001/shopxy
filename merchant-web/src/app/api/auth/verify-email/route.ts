import { NextResponse } from "next/server";
import { z } from "zod";
import { authResultSchema } from "@/features/auth/types";
import {
  ALLOWED_ROLE,
  ROLE_REJECTED_MESSAGE,
  backendFetch,
  extractError,
  fetchMeUser,
  setSessionCookies,
} from "@/server/auth/session";

const bodySchema = z.object({
  email: z.string().trim().email(),
  otp: z.string().trim().regex(/^\d{6}$/, "Enter the 6-digit code."),
});

// POST /api/auth/verify-email — confirm the signup OTP. On success the backend
// creates the account and returns a session, which we persist as httpOnly
// cookies (same as login/register-fallback).
export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = bodySchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0]?.message ?? "Enter the 6-digit code." },
      { status: 400 },
    );
  }

  const res = await backendFetch("/auth/verify-email", {
    method: "POST",
    body: JSON.stringify({ email: parsed.data.email, otp: parsed.data.otp }),
  });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "That code didn't work.") },
      { status: res.status === 429 ? 429 : 400 },
    );
  }

  const result = authResultSchema.safeParse(await res.json());
  if (!result.success) {
    return NextResponse.json(
      { error: "Unexpected response from the server." },
      { status: 502 },
    );
  }
  if (result.data.user.role !== ALLOWED_ROLE) {
    return NextResponse.json({ error: ROLE_REJECTED_MESSAGE }, { status: 403 });
  }

  await setSessionCookies(result.data);
  const user = (await fetchMeUser(result.data.accessToken)) ?? result.data.user;
  return NextResponse.json({ user }, { status: 201 });
}
