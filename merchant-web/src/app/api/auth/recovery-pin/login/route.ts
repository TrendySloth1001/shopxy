import { NextResponse } from "next/server";
import { recoveryPinLoginSchema } from "@/features/auth/schema";
import { authResultSchema } from "@/features/auth/types";
import {
  ALLOWED_ROLE,
  ROLE_REJECTED_MESSAGE,
  backendFetch,
  extractError,
  fetchMeUser,
  setSessionCookies,
} from "@/server/auth/session";

// POST /api/auth/recovery-pin/login — fallback sign-in for Google-only
// accounts when Google itself isn't reachable. Same cookie contract as
// /api/auth/login.
export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = recoveryPinLoginSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Enter a valid email and PIN." },
      { status: 400 },
    );
  }

  const res = await backendFetch("/auth/recovery-pin/login", {
    method: "POST",
    body: JSON.stringify(parsed.data),
  });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Invalid email or recovery PIN.") },
      { status: res.status === 401 ? 401 : 400 },
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
  return NextResponse.json({ user });
}
