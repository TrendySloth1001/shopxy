import { NextResponse } from "next/server";
import { registerWireSchema } from "@/features/auth/schema";
import { authResultSchema } from "@/features/auth/types";
import {
  ALLOWED_ROLE,
  ROLE_REJECTED_MESSAGE,
  backendFetch,
  extractError,
  fetchMeUser,
  setSessionCookies,
} from "@/server/auth/session";

// POST /api/auth/register — customer signup. Creates a CUSTOMER account on the
// backend (no shop) and persists the session as httpOnly cookies. Consent
// literals are forwarded as the backend requires them.
export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = registerWireSchema.safeParse(json);
  if (!parsed.success) {
    const first =
      parsed.error.issues[0]?.message ?? "Please check the form and try again.";
    return NextResponse.json({ error: first }, { status: 400 });
  }

  const res = await backendFetch("/auth/register", {
    method: "POST",
    body: JSON.stringify({
      name: parsed.data.name,
      email: parsed.data.email,
      password: parsed.data.password,
      role: "CUSTOMER",
      acceptedTerms: true,
      acceptedPrivacy: true,
    }),
  });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not create your account.") },
      { status: res.status === 409 ? 409 : 400 },
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
