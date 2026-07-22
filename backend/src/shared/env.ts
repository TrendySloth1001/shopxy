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

/**
 * Read a required *secret* — like {@link requireEnv}, but also refuses to start
 * if the value is too short to be safe. HS256 signing is only as strong as the
 * key; a short/guessable `JWT_*_SECRET` undermines every token. Enforce at least
 * `minChars` (default 32 ≈ 256 bits) so a weak secret can never reach prod.
 */
export function requireSecret(name: string, minChars = 32): string {
  const v = requireEnv(name);
  if (v.trim().length < minChars) {
    throw new Error(
      `${name} is too weak — must be at least ${minChars} characters ` +
        `(got ${v.trim().length}). Generate one with \`openssl rand -base64 48\`.`,
    );
  }
  return v;
}
