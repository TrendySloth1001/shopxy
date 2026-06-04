import { Request, Response, NextFunction } from 'express';
import { Role } from '@prisma/client';
import { isPlatformAdminLive } from './requireAuth.js';

/// Express middleware factory: rejects authenticated users whose
/// `req.user.role` is not in the allowed set. Must run AFTER `requireAuth`,
/// which is what populates `req.user`. Merchant-only routes use
/// `requireRole(Role.OWNER)`; customer-only routes use `requireRole(Role.CUSTOMER)`.
export function requireRole(...allowed: Role[]) {
  return function (req: Request, res: Response, next: NextFunction): void {
    const role = req.user?.role;
    if (!role || !allowed.includes(role)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    next();
  };
}

/// Gate for cross-shop / platform-wide actions (banner curation, taxonomy
/// edits, collection authoring). Independent of role: any user can be
/// flagged as a platform admin by toggling `users.is_platform_admin`.
export async function requirePlatformAdmin(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const userId = req.user?.sub;
  // Re-validate against the live (cached) DB flag rather than trusting the
  // JWT claim — closes the window where a revoked admin keeps access on
  // optionalAuth mounts (e.g. category writes) until token expiry (B-AUTH-4).
  try {
    if (!userId || !(await isPlatformAdminLive(userId))) {
      res.status(403).json({ error: 'Platform admin only' });
      return;
    }
  } catch (err) {
    next(err);
    return;
  }
  next();
}
