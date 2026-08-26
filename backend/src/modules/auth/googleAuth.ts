import { OAuth2Client } from 'google-auth-library';
import { logger } from '../../shared/logging/logger.js';

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

export async function verifyGoogleIdToken(idToken: string): Promise<GoogleProfile | null> {
  if (!client) {
    logger.warn('google sign-in attempted but no GOOGLE_CLIENT_ID_* is configured');
    return null;
  }
  try {
    const ticket = await client.verifyIdToken({ idToken, audience: CLIENT_IDS });
    const payload = ticket.getPayload();
    if (!payload || !payload.sub || !payload.email) return null;
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
