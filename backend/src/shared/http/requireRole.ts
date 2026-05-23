import { Request, Response, NextFunction } from 'express';

/// Express middleware factory: rejects authenticated users whose
/// `req.user.role` is not in the allowed set. Must run AFTER `requireAuth`,
/// which is what populates `req.user`. Owner-only merchant routes use
/// `requireRole('OWNER')`; customer-only routes (none yet) would use
/// `requireRole('CUSTOMER')`.
export function requireRole(...allowed: string[]) {
  return function (req: Request, res: Response, next: NextFunction): void {
    const role = req.user?.role;
    if (!role || !allowed.includes(role)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    next();
  };
}
