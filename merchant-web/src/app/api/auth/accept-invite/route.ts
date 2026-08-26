import { NextResponse } from "next/server";
import { acceptInviteSchema } from "@/features/auth/schema";
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
  const parsed = acceptInviteSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json(
      { error: parsed.error.issues[0]?.message ?? "Invalid input." },
      { status: 400 },
    );
  }

  const res = await backendFetch("/auth/accept-invite", {
    method: "POST",
    body: JSON.stringify({
      token: parsed.data.token,
      name: parsed.data.name,
      password: parsed.data.password,
    }),
  });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Could not accept this invitation.") },
      { status: 400 },
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
