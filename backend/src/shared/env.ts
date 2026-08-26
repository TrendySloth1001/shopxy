export function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v || !v.trim()) {
    throw new Error(`${name} is required — refusing to start without it`);
  }
  return v;
}

export function envOr(name: string, fallback: string): string {
  const v = process.env[name];
  return v && v.trim() ? v : fallback;
}

export function envBool(name: string, fallback = false): boolean {
  const v = process.env[name];
  if (v === undefined || !v.trim()) return fallback;
  return ['1', 'true', 'yes', 'on'].includes(v.trim().toLowerCase());
}

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
