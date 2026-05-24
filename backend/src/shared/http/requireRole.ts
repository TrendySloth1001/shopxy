import { Request, Response, NextFunction } from 'express';
import { Role } from '@prisma/client';

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
export function requirePlatformAdmin(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (!req.user?.isPlatformAdmin) {
    res.status(403).json({ error: 'Platform admin only' });
    return;
  }
  next();
}
