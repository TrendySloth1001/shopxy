import { NextResponse } from "next/server";
import { cookies } from "next/headers";
import { z } from "zod";
import {
  BACKEND_ENVIRONMENTS,
  DEFAULT_BACKEND_BASE_URL,
  ENV_COOKIE,
  environmentById,
  environmentMatching,
} from "@/shared/config/environments";
import {
  clearSessionCookies,
  getCurrentUser,
  resolveBackendBaseUrl,
} from "@/server/auth/session";
import { isDeveloperAccount } from "@/shared/config/developer";
import { env } from "@/shared/config/env";

const NOT_FOUND = () => new NextResponse(null, { status: 404 });

async function requireDeveloper(): Promise<boolean> {
  const user = await getCurrentUser();
  return isDeveloperAccount(user?.email);
}

export async function GET() {
  if (!(await requireDeveloper())) return NOT_FOUND();

  const store = await cookies();
  const chosen = environmentById(store.get(ENV_COOKIE)?.value);
  const effective = await resolveBackendBaseUrl();

  return NextResponse.json({
    options: BACKEND_ENVIRONMENTS.map(({ id, label, description }) => ({
      id,
      label,
      description,
    })),
    currentId: chosen?.id ?? environmentMatching(effective)?.id ?? null,
    isDefault: !chosen,
  });
}

const bodySchema = z.object({
  id: z.enum(
    BACKEND_ENVIRONMENTS.map((e) => e.id) as [string, ...string[]],
  ),
});

export async function POST(req: Request) {
  if (!(await requireDeveloper())) return NOT_FOUND();

  const parsed = bodySchema.safeParse(await req.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "Unknown environment" }, { status: 400 });
  }
  const target = environmentById(parsed.data.id);
  if (!target) {
    return NextResponse.json({ error: "Unknown environment" }, { status: 400 });
  }

  await clearSessionCookies();

  const store = await cookies();
  if (target.baseUrl === DEFAULT_BACKEND_BASE_URL) {
    store.delete(ENV_COOKIE);
  } else {
    store.set(ENV_COOKIE, target.id, {
      httpOnly: true,
      sameSite: "lax",
      secure: env.isProd,
      path: "/",
      maxAge: 30 * 24 * 60 * 60,
    });
  }

  return NextResponse.json({ ok: true });
}
