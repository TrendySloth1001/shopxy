import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { Role } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { requireEnv } from '../env.js';

/// JWT payload as signed at login / refresh. `shopId` is included for
/// merchant accounts so per-request DB lookup is avoided; for customer
/// accounts it stays undefined.
export interface AuthPayload {
  sub: number;
  email: string;
  role: Role;
  isPlatformAdmin: boolean;
  /// Multi-tenant scope. Set for OWNER accounts that have a Shop row.
  /// Undefined for CUSTOMER accounts and for OWNERs who registered
  /// before the post-signup shop-creation hook (a corner case).
  shopId?: number;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthPayload;
    }
  }
}

const ACCESS_SECRET = requireEnv('JWT_ACCESS_SECRET');

/// Tiny in-process cache so we don't re-query `Shop` for every request
/// when an old JWT (issued before the multi-tenant migration) lacks
/// `shopId`. 60s is short enough that a brand-new shop becomes
/// reachable quickly without forcing logout/re-login.
const shopIdCache = new Map<number, { shopId: number | undefined; expiresAt: number }>();
const CACHE_TTL_MS = 60_000;

async function resolveShopIdForUser(userId: number): Promise<number | undefined> {
  const cached = shopIdCache.get(userId);
  if (cached && cached.expiresAt > Date.now()) return cached.shopId;
  const shop = await prisma.shop.findUnique({
    where: { ownerUserId: userId },
    select: { id: true },
  });
  const shopId = shop?.id;
  shopIdCache.set(userId, { shopId, expiresAt: Date.now() + CACHE_TTL_MS });
  return shopId;
}

export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Authentication required' });
    return;
  }
  const token = header.slice(7);
  let payload: AuthPayload;
  try {
    payload = jwt.verify(token, ACCESS_SECRET, { algorithms: ['HS256'] }) as unknown as AuthPayload;
  } catch {
    res.status(401).json({ error: 'Token expired or invalid' });
    return;
  }

  // Hydrate shopId from the cache/DB when the JWT didn't carry one
  // (older JWTs from before the multi-tenant cut). Cheap: indexed by
  // the @unique(ownerUserId) constraint on Shop.
  if (payload.shopId === undefined && payload.role === 'OWNER') {
    payload.shopId = await resolveShopIdForUser(payload.sub);
  }

  req.user = payload;
  next();
}

/// Force-invalidate the cached shopId for a user. Called after a Shop
/// row is created or its ownership transfers, so the next request
/// sees the new value without waiting for the TTL.
export function invalidateShopIdCache(userId: number): void {
  shopIdCache.delete(userId);
}
