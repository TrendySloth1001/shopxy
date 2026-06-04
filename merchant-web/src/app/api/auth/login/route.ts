import { NextResponse } from "next/server";
import { loginSchema } from "@/features/auth/schema";
import { authResultSchema } from "@/features/auth/types";
import {
  ALLOWED_ROLE,
  ROLE_REJECTED_MESSAGE,
  backendFetch,
  extractError,
  fetchMeUser,
  setSessionCookies,
} from "@/server/auth/session";

// POST /api/auth/login — validate, proxy to the backend, gate on role, and on
// success persist the token pair as httpOnly cookies. Returns the safe user
// (no tokens ever cross to the browser).
export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = loginSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: "Enter a valid email and password." },
      { status: 400 },
    );
  }

  const res = await backendFetch("/auth/login", {
    method: "POST",
    body: JSON.stringify(parsed.data),
  });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Invalid email or password.") },
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

  // Gate on role BEFORE persisting any session.
  if (result.data.user.role !== ALLOWED_ROLE) {
    return NextResponse.json({ error: ROLE_REJECTED_MESSAGE }, { status: 403 });
  }

  await setSessionCookies(result.data);
  // The login response omits shopRole/shopId — re-fetch the enriched view.
  const user = (await fetchMeUser(result.data.accessToken)) ?? result.data.user;
  return NextResponse.json({ user });
}
