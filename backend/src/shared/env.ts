/**
 * Read a required environment variable. Throws on import-time if the var is
 * missing — fail fast so production deployments don't silently fall back to
 * an insecure default.
 */
export function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v || !v.trim()) {
    throw new Error(`${name} is required — refusing to start without it`);
  }
  return v;
}

/** Read an env var, returning `fallback` when unset/empty. */
export function envOr(name: string, fallback: string): string {
  const v = process.env[name];
  return v && v.trim() ? v : fallback;
}
