import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AuthPayload } from './requireAuth.js';
import { JWT_ACCESS_SECRET as ACCESS_SECRET } from '../authSecrets.js';

/// Hydrates `req.user` when a valid Bearer token is present, otherwise
/// leaves it undefined and continues. Use on PUBLIC marketplace
/// endpoints so the own-shop guard can fire when a logged-in customer
/// is browsing, while anonymous visitors still see the page.
///
/// Never rejects: a bad / expired token is treated the same as no
/// token. That's deliberate — the routes are public, the auth is an
/// enrichment.
export function optionalAuth(req: Request, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    next();
    return;
  }
  const token = header.slice(7);
  try {
    // Pin the algorithm (mirror requireAuth) so a token can't be coerced
    // into a weaker/none verification on these public-but-privilege-
    // bearing mounts (B-AUTH-4).
    req.user = jwt.verify(token, ACCESS_SECRET, {
      algorithms: ['HS256'],
    }) as unknown as AuthPayload;
  } catch {
    // Silently ignore — endpoint is public.
  }
  next();
}
