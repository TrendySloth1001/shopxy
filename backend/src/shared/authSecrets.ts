import { requireSecret } from './env.js';

/**
 * Single source of truth for the JWT signing secrets. Read + strength-validated
 * exactly once here (see {@link requireSecret}), then imported everywhere a
 * token is signed or verified — auth.service, requireAuth, optionalAuth,
 * cashier/override — so the secrets are never re-read (or weakly validated) in
 * scattered `requireEnv` calls.
 */
export const JWT_ACCESS_SECRET = requireSecret('JWT_ACCESS_SECRET');
export const JWT_REFRESH_SECRET = requireSecret('JWT_REFRESH_SECRET');
