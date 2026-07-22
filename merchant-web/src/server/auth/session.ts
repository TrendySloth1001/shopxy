import "server-only";
import { cookies } from "next/headers";
import { env } from "@/shared/config/env";
import {
  authUserSchema,
  tokenPairSchema,
  type AuthUser,
} from "@/features/auth/types";

/**
 * Server-only session layer for the Backend-for-Frontend (BFF).
 *
 * The browser never sees the JWTs: the access + refresh tokens issued by the
 * ShopXY backend are stored in httpOnly, SameSite=Lax cookies set by the
 * `/api/auth/*` route handlers. This is the web equivalent of the mobile apps'
 * encrypted secure storage (see `frontend/lib/core/auth/token_manager.dart`) —
 * tokens out of reach of XSS, and the backend URL never shipped to the client.
 *
 * Refresh rotation mirrors the mobile ApiClient: on a 401 we transparently
 * exchange the refresh token for a new pair and retry once.
 */

// App-scoped cookie names. merchant-web and customer-web run on the same host
// in dev (localhost:3010 / :3009) and cookies are NOT port-scoped, so identical
// names would let one app read the other's session. Distinct prefixes keep the
// two sessions isolated. (`sxm_` = ShopXY merchant.)
const ACCESS_COOKIE = "sxm_access";
const REFRESH_COOKIE = "sxm_refresh";
/** Matches the backend refresh-token lifetime (7 days). */
const REFRESH_MAX_AGE = 7 * 24 * 60 * 60;
/**
 * Matches the backend access-token lifetime (15 min). The access cookie is
 * scoped to the token's own TTL so a stale access JWT isn't kept presentable
 * for days; the refresh cookie (above) carries the long-lived session and
 * `authedFetch`/`getCurrentUser` transparently re-mint the access token from it.
 */
const ACCESS_MAX_AGE = 15 * 60;

/**
 * This app admits OWNER (merchant) accounts only. A CUSTOMER account that
 * authenticates here is rejected and never persisted as a session — parity
 * with the Flutter merchant app's `customerAccountBlocked` gate.
 */
export const ALLOWED_ROLE = "OWNER" as const;
export const ROLE_REJECTED_MESSAGE =
  "This is a customer account. Please use the ShopXY customer app to sign in.";

export type TokenPair = { accessToken: string; refreshToken: string };

function cookieOptions(maxAge: number) {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    secure: env.isProd,
    path: "/",
    maxAge,
  };
}

export async function setSessionCookies(tokens: TokenPair): Promise<void> {
  const store = await cookies();
  store.set(ACCESS_COOKIE, tokens.accessToken, cookieOptions(ACCESS_MAX_AGE));
  store.set(REFRESH_COOKIE, tokens.refreshToken, cookieOptions(REFRESH_MAX_AGE));
}

export async function clearSessionCookies(): Promise<void> {
  const store = await cookies();
  store.delete(ACCESS_COOKIE);
  store.delete(REFRESH_COOKIE);
}

async function getRefreshToken(): Promise<string | null> {
  const store = await cookies();
  return store.get(REFRESH_COOKIE)?.value ?? null;
}

/**
 * Raw fetch to the backend. Never throws on non-2xx — returns the Response.
 * Defaults to a JSON content-type, but leaves FormData bodies alone so fetch
 * can set the multipart boundary itself (used by the avatar upload).
 */
export function backendFetch(
  path: string,
  init?: RequestInit,
): Promise<Response> {
  const url = `${env.API_BASE_URL}/${path.replace(/^\/+/, "")}`;
  const headers: Record<string, string> = {
    ...(init?.headers as Record<string, string> | undefined),
  };
  const isForm =
    typeof FormData !== "undefined" && init?.body instanceof FormData;
  if (!isForm && !("Content-Type" in headers) && !("content-type" in headers)) {
    headers["Content-Type"] = "application/json";
  }
  return fetch(url, { ...init, headers, cache: "no-store" });
}

/** Flatten a backend error body (string | zod flatten) to one message. */
export async function extractError(
  res: Response,
  fallback = "Something went wrong",
): Promise<string> {
  try {
    const body = (await res.json()) as {
      error?: string | { fieldErrors?: Record<string, string[]>; formErrors?: string[] };
    };
    const err = body?.error;
    if (typeof err === "string") return err;
    if (err?.fieldErrors) {
      for (const messages of Object.values(err.fieldErrors)) {
        if (Array.isArray(messages) && messages.length > 0) return messages[0];
      }
    }
    if (err?.formErrors && err.formErrors.length > 0) return err.formErrors[0];
  } catch {
    // non-JSON body — fall through to the fallback
  }
  return fallback;
}

function fetchMe(accessToken: string): Promise<Response> {
  return backendFetch("/auth/me", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
}

/** Exchange the stored refresh token for a fresh pair, persisting the result. */
async function tryRefresh(): Promise<TokenPair | null> {
  const refreshToken = await getRefreshToken();
  if (!refreshToken) return null;
  const res = await backendFetch("/auth/refresh", {
    method: "POST",
    body: JSON.stringify({ refreshToken }),
  });
  if (!res.ok) return null;
  const parsed = tokenPairSchema.safeParse(await res.json());
  if (!parsed.success) return null;
  await setSessionCookies(parsed.data);
  return parsed.data;
}

/** Fetch the enriched `/auth/me` user for a known-good access token. */
export async function fetchMeUser(accessToken: string): Promise<AuthUser | null> {
  const res = await fetchMe(accessToken);
  if (!res.ok) return null;
  const parsed = authUserSchema.safeParse(await res.json());
  return parsed.success ? parsed.data : null;
}

/**
 * Read-only session peek, safe to call from a **Server Component** (layout).
 *
 * Unlike {@link getCurrentUser}, this never refreshes or mutates cookies —
 * Server Components cannot set cookies, so this only trusts a still-valid access
 * cookie. Returns the user when the 15-min access token is present and good;
 * returns null (no backend call) when it's absent or expired, leaving the client
 * `AuthProvider` to bootstrap via the route handler (which *can* rotate cookies).
 *
 * Passing the result as `initialUser` lets a logged-in merchant render authed on
 * the server for the common hot path, skipping the blocking client
 * `/api/auth/me` round-trip on every navigation.
 */
export async function peekSessionUser(): Promise<AuthUser | null> {
  const store = await cookies();
  const access = store.get(ACCESS_COOKIE)?.value ?? null;
  if (!access) return null;
  const user = await fetchMeUser(access);
  if (!user || user.role !== ALLOWED_ROLE) return null;
  return user;
}

async function currentAccessToken(): Promise<string | null> {
  const store = await cookies();
  return store.get(ACCESS_COOKIE)?.value ?? null;
}

/**
 * Call a protected backend endpoint with the caller's bearer token, refreshing
 * once on a 401 (mirrors the mobile ApiClient retry). Returns null when there
 * is no valid session — the route handler should answer 401 in that case.
 */
export async function authedFetch(
  path: string,
  init?: RequestInit,
): Promise<Response | null> {
  let token = await currentAccessToken();
  if (!token) {
    const refreshed = await tryRefresh();
    if (!refreshed) return null;
    token = refreshed.accessToken;
  }
  const call = (bearer: string) =>
    backendFetch(path, {
      ...init,
      headers: { ...init?.headers, Authorization: `Bearer ${bearer}` },
    });

  let res = await call(token);
  if (res.status === 401) {
    const refreshed = await tryRefresh();
    if (!refreshed) {
      await clearSessionCookies();
      return null;
    }
    res = await call(refreshed.accessToken);
  }
  return res;
}

/**
 * Resolve the current session user, refreshing once on a 401. Returns null
 * (and clears the session) when no valid, role-appropriate session exists.
 * Only call from a Route Handler — it may set/clear cookies.
 */
export async function getCurrentUser(): Promise<AuthUser | null> {
  const store = await cookies();
  let access = store.get(ACCESS_COOKIE)?.value ?? null;

  if (!access) {
    const refreshed = await tryRefresh();
    if (!refreshed) return null;
    access = refreshed.accessToken;
  }

  let res = await fetchMe(access);
  if (res.status === 401) {
    const refreshed = await tryRefresh();
    if (!refreshed) {
      await clearSessionCookies();
      return null;
    }
    res = await fetchMe(refreshed.accessToken);
  }
  if (!res.ok) return null;

  const parsed = authUserSchema.safeParse(await res.json());
  if (!parsed.success) return null;

  if (parsed.data.role !== ALLOWED_ROLE) {
    // Cross-app account — never expose it as a session in this app.
    await clearSessionCookies();
    return null;
  }
  return parsed.data;
}
