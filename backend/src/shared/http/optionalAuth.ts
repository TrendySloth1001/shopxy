import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AuthPayload } from './requireAuth.js';

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`${name} is required — refusing to start with a default secret`);
  return v;
}

const ACCESS_SECRET = requireEnv('JWT_ACCESS_SECRET');

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
    req.user = jwt.verify(token, ACCESS_SECRET) as unknown as AuthPayload;
  } catch {
    // Silently ignore — endpoint is public.
  }
  next();
}
