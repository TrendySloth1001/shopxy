import { OAuth2Client } from 'google-auth-library';
import { logger } from '../../shared/logging/logger.js';

/**
 * Client IDs for every platform that can mint a Google ID token for this
 * app (web, Android, iOS) — all three are valid audiences for the same
 * backend, since one login endpoint serves every client. Optional: unset
 * means Google sign-in is inert (matches this project's pattern for
 * optional integrations — e.g. Razorpay, HSN_SEMANTIC — rather than
 * failing boot over a feature that isn't configured yet).
 */
const CLIENT_IDS = [
  process.env.GOOGLE_CLIENT_ID_WEB,
  process.env.GOOGLE_CLIENT_ID_ANDROID,
  process.env.GOOGLE_CLIENT_ID_IOS,
].filter((id): id is string => !!id && id.trim().length > 0);

const client = CLIENT_IDS.length > 0 ? new OAuth2Client() : null;

export function googleAuthConfigured(): boolean {
  return client !== null;
}

export type GoogleProfile = {
  googleId: string;
  email: string;
  name: string;
};

/**
 * Verify a Google-issued ID token's signature, issuer, audience and
 * expiry, and return the profile fields we trust. Returns `null` for any
 * invalid/unconfigured/unverified-email token — callers translate that
 * into a generic 401 so failures never leak *why* a token was rejected.
 */
export async function verifyGoogleIdToken(idToken: string): Promise<GoogleProfile | null> {
  if (!client) {
    logger.warn('google sign-in attempted but no GOOGLE_CLIENT_ID_* is configured');
    return null;
  }
  try {
    const ticket = await client.verifyIdToken({ idToken, audience: CLIENT_IDS });
    const payload = ticket.getPayload();
    if (!payload || !payload.sub || !payload.email) return null;
    // Google only sets this false for edge cases (e.g. some legacy G Suite
    // domains) where the address isn't actually confirmed — don't trust it
    // for account creation/linking if so.
    if (payload.email_verified !== true) return null;
    return {
      googleId: payload.sub,
      email: payload.email.toLowerCase().trim(),
      name: (payload.name ?? payload.email.split('@')[0]).trim(),
    };
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'google id token verification failed');
    return null;
  }
}
