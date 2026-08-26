import { NextResponse } from "next/server";
import { z } from "zod";
import { googleAuthResultSchema } from "@/features/auth/types";
import {
  ALLOWED_ROLE,
  ROLE_REJECTED_MESSAGE,
  backendFetch,
  extractError,
  fetchMeUser,
  setSessionCookies,
} from "@/server/auth/session";

const idTokenSchema = z.object({ idToken: z.string().min(10) });

export async function POST(req: Request) {
  const json = await req.json().catch(() => null);
  const parsed = idTokenSchema.safeParse(json);
  if (!parsed.success) {
    return NextResponse.json({ error: "idToken required" }, { status: 400 });
  }

  const res = await backendFetch("/auth/google", {
    method: "POST",
    body: JSON.stringify(parsed.data),
  });
  if (!res.ok) {
    return NextResponse.json(
      { error: await extractError(res, "Google sign-in failed.") },
      { status: res.status === 403 ? 403 : 401 },
    );
  }

  const result = googleAuthResultSchema.safeParse(await res.json());
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
  return NextResponse.json({ user, needsPinSetup: result.data.needsPinSetup });
}
