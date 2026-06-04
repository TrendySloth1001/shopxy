import "server-only";
import { z } from "zod";

/**
 * Server-only environment config. Validated once at module load so a missing
 * or malformed value fails fast at boot, never at request time. (CLAUDE.md §3.)
 *
 * `API_BASE_URL` is the ShopXY backend the BFF route handlers proxy to. It is
 * deliberately NOT a `NEXT_PUBLIC_*` var — the browser never talks to the
 * backend directly, so the URL (and the bearer tokens) stay server-side.
 *
 * Trailing slash is normalised away here so callers can join paths cleanly.
 */
const schema = z.object({
  // Defaulted to the shared dev tunnel (same host the Flutter apps point at via
  // AppConfig.apiBaseUrl) so the app runs out of the box in development. In
  // production this MUST be provided explicitly.
  API_BASE_URL: z
    .string()
    .url()
    .default("https://qjhcp0ph-3003.inc1.devtunnels.ms/"),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  throw new Error(
    `Invalid environment configuration:\n${parsed.error.toString()}`,
  );
}

export const env = {
  ...parsed.data,
  API_BASE_URL: parsed.data.API_BASE_URL.replace(/\/+$/, ""),
  isProd: parsed.data.NODE_ENV === "production",
} as const;
