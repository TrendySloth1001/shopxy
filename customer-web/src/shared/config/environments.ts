import "server-only";
import { env } from "./env";

/**
 * The backends this BFF can proxy to — the customer-web mirror of
 * `merchant-web/src/shared/config/environments.ts` and the Flutter apps'
 * `lib/core/config/app_environment.dart`. Each environment runs its own
 * database, so choosing a backend chooses the data you see.
 *
 * This is an allow-list, not a free-text field, and deliberately so: the BFF
 * attaches the signed-in customer's bearer token to every upstream call, so a
 * switcher that accepted a typed-in URL would be a one-request way to forward
 * that token to any host on the internet. Adding an environment is a code
 * change.
 *
 * Server-only. The `baseUrl`s never reach the browser (see `env.ts`); the
 * picker is sent `{ id, label, description }` and nothing else.
 */
export type BackendEnvironment = {
  /** Stable key stored in the cookie. Never renamed. */
  id: string;
  label: string;
  description: string;
  /** No trailing slash — `backendFetch` joins with an explicit `/`. */
  baseUrl: string;
};

export const BACKEND_ENVIRONMENTS: readonly BackendEnvironment[] = [
  {
    id: "production",
    label: "Production",
    description: "Live shops and real money",
    baseUrl: "https://backendshopxy.cloudnsofts.com",
  },
  {
    id: "tunnel",
    label: "Dev tunnel",
    description: "The shared dev backend",
    baseUrl: "https://qjhcp0ph-3003.inc1.devtunnels.ms",
  },
  {
    id: "local",
    label: "Local",
    description: "localhost:3003, alongside this Next server",
    baseUrl: "http://localhost:3003",
  },
] as const;

/**
 * Cookie carrying the chosen environment.
 *
 * `sxc_` prefixed to match this app's session cookies, and distinct from
 * merchant-web's `sxm_env`: the two apps share a host in development and
 * cookies are not port-scoped, so a shared name would have one app's switch
 * silently redirect the other's proxy. httpOnly so only our own route handler
 * can set it — page scripts can neither read which backend is in use nor
 * redirect the proxy at one.
 */
export const ENV_COOKIE = "sxc_env";

export function environmentById(id: string | undefined | null) {
  if (!id) return undefined;
  return BACKEND_ENVIRONMENTS.find((e) => e.id === id);
}

/**
 * Which entry `baseUrl` corresponds to, or undefined when it matches none —
 * the normal case for a deployment whose `API_BASE_URL` points somewhere
 * bespoke.
 */
export function environmentMatching(baseUrl: string) {
  const normalise = (u: string) => u.trim().toLowerCase().replace(/\/+$/, "");
  const needle = normalise(baseUrl);
  return BACKEND_ENVIRONMENTS.find((e) => normalise(e.baseUrl) === needle);
}

/** The deployment's configured backend, used when no environment is chosen. */
export const DEFAULT_BACKEND_BASE_URL = env.API_BASE_URL;
