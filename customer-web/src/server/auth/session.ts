import "server-only";
import { cookies } from "next/headers";
import { env } from "@/shared/config/env";
import {
  DEFAULT_BACKEND_BASE_URL,
  ENV_COOKIE,
  environmentById,
} from "@/shared/config/environments";
import {
  authUserSchema,
  tokenPairSchema,
  type AuthUser,
} from "@/features/auth/types";

const ACCESS_COOKIE = "sxc_access";
const REFRESH_COOKIE = "sxc_refresh";
const REFRESH_MAX_AGE = 7 * 24 * 60 * 60;
const ACCESS_MAX_AGE = 15 * 60;

export const ALLOWED_ROLE = "CUSTOMER" as const;
export const ROLE_REJECTED_MESSAGE =
  "This is a merchant account. Please use the ShopXY merchant app to sign in.";

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

export async function resolveBackendBaseUrl(): Promise<string> {
  const store = await cookies();
  return (
    environmentById(store.get(ENV_COOKIE)?.value)?.baseUrl ??
    DEFAULT_BACKEND_BASE_URL
  );
}

export async function backendFetch(
  path: string,
  init?: RequestInit,
): Promise<Response> {
  const url = `${await resolveBackendBaseUrl()}/${path.replace(/^\/+/, "")}`;
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
  }
  return fallback;
}

function fetchMe(accessToken: string): Promise<Response> {
  return backendFetch("/auth/me", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
}

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

export async function fetchMeUser(accessToken: string): Promise<AuthUser | null> {
  const res = await fetchMe(accessToken);
  if (!res.ok) return null;
  const parsed = authUserSchema.safeParse(await res.json());
  return parsed.success ? parsed.data : null;
}

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
    await clearSessionCookies();
    return null;
  }
  return parsed.data;
}
