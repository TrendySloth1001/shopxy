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
/// **This middleware performs a database lookup** (1 row by unique
/// index per request). The name was changed from `resolveShop` to
/// `loadShopMiddleware` so the DB hit is obvious at the route
/// definition site; `resolveShop` is re-exported below for back-compat.
///
/// Per-request short-circuit: if `req.shopId` is already populated
/// (e.g. by an upstream middleware or a prior call in the same
/// request lifecycle), we skip the round-trip entirely. If the
/// merchant product API ever becomes hot enough that this shows up
/// in p95, move the shopId into the JWT claims (signed at login,
/// refreshed on shop rename) and drop the DB hit altogether.
export async function loadShopMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  // Per-request cache: once req.shopId is set, subsequent invocations
  // of this middleware on the same request are no-ops.
  if (typeof req.shopId === 'number') {
    next();
    return;
  }

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

/// Back-compat alias for callers still importing the old name.
/// Prefer `loadShopMiddleware` in new code — the name makes the DB
/// lookup obvious at the route definition.
export const resolveShop = loadShopMiddleware;
