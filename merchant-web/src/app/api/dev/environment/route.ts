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

/**
 * Developer-only backend switcher — the web half of the Flutter merchant
 * app's Settings → Environment screen.
 *
 * The choice is stored in an httpOnly cookie scoped to this browser, so a
 * developer pointing themselves at a dev backend never moves any other
 * merchant's requests. The gate is enforced here rather than in the UI: the
 * settings section simply renders nothing when this endpoint 404s, which
 * keeps the developer address off the client bundle entirely.
 *
 * Both verbs answer 404 (not 403) for everyone else, so the endpoint doesn't
 * advertise its own existence.
 */

const NOT_FOUND = () => new NextResponse(null, { status: 404 });

async function requireDeveloper(): Promise<boolean> {
  const user = await getCurrentUser();
  return isDeveloperAccount(user?.email);
}

/** The picker's data. Deliberately carries no `baseUrl` — see `env.ts`. */
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
    // Null when the deployment's configured backend isn't one of the listed
    // entries — the picker then shows nothing selected rather than lying.
    currentId: chosen?.id ?? environmentMatching(effective)?.id ?? null,
    /** True when no choice is stored and the server default is in force. */
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

  // Sign out BEFORE repointing: the refresh token being revoked belongs to
  // the environment we're leaving, and the new one would reject it. Clearing
  // the session is also what makes the switch safe — a JWT minted by one
  // backend is meaningless to another, and every cached page would be showing
  // the wrong database.
  await clearSessionCookies();

  const store = await cookies();
  if (target.baseUrl === DEFAULT_BACKEND_BASE_URL) {
    // Picking the deployment's own backend means "no override" — drop the
    // cookie rather than pinning a value that would then survive a config
    // change to API_BASE_URL.
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
