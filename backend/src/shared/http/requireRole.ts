import { Request, Response, NextFunction } from 'express';
import { Role } from '@prisma/client';
import { isPlatformAdminLive } from './requireAuth.js';

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

export async function requirePlatformAdmin(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const userId = req.user?.sub;
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
