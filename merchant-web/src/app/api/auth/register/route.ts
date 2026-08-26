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
      role: "OWNER",
      acceptedTerms: true,
      acceptedPrivacy: true,
    }),
  });
  if (!res.ok) {
    if (res.status === 503) {
      const body = (await res.json().catch(() => null)) as { message?: string } | null;
      return NextResponse.json(
        {
          error:
            body?.message ??
            "We couldn't send your verification code just now. Please try again in a few minutes.",
        },
        { status: 503 },
      );
    }
    return NextResponse.json(
      { error: await extractError(res, "Could not create your account.") },
      { status: res.status === 409 ? 409 : 400 },
    );
  }

  const payload: unknown = await res.json();
  if (
    payload &&
    typeof payload === "object" &&
    (payload as { pending?: unknown }).pending === true
  ) {
    const email = (payload as { email?: unknown }).email;
    return NextResponse.json(
      { pending: true, email: typeof email === "string" ? email : parsed.data.email },
      { status: 200 },
    );
  }

  const result = authResultSchema.safeParse(payload);
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
