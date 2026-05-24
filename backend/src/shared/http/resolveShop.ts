import { Request, Response, NextFunction } from 'express';
import prisma from '../../infra/db/prisma.js';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      shopId?: number;
    }
  }
}

/// Express middleware: resolves the caller's shopId from their user
/// id and attaches it to req.shopId. Must run AFTER requireAuth +
/// requireRole('OWNER'). Returns 404 if the OWNER has no shop row
/// (shouldn't happen post-Phase 0 backfill — but explicit beats silent).
///
/// Lookup cost: 1 row by unique index per request. If the merchant
/// product API ever becomes hot enough that this shows up in p95,
/// move the shopId into the JWT claims (signed at login, refreshed on
/// shop rename) and drop the DB hit altogether.
export async function resolveShop(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const userId = req.user?.sub;
  if (!userId) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }
  const shop = await prisma.shop.findUnique({
    where: { ownerUserId: userId },
    select: { id: true },
  });
  if (!shop) {
    res.status(404).json({ error: 'No shop linked to this account' });
    return;
  }
  req.shopId = shop.id;
  next();
}
