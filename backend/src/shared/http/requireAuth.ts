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
  /// Standard JWT issued-at (seconds). Always present on tokens minted
  /// by this server; declared optional so older tokens (if any) parse
  /// without breaking. Used to compare against `User.tokensValidFrom`.
  iat?: number;
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

/// Per-user "tokens issued before this stamp are invalid" cache. The
/// requireAuth hot path can't afford a SELECT-per-request; this lets
/// us cache the floor for a minute. Bumped via [bumpTokensValidFrom]
/// at password-change / logout-all time so the next refresh picks up
/// the new floor within the TTL.
const tokensValidFromCache = new Map<number, { stamp: Date | null; expiresAt: number }>();
const TOKENS_VALID_CACHE_TTL_MS = 60_000;

async function getTokensValidFrom(userId: number): Promise<Date | null> {
  const cached = tokensValidFromCache.get(userId);
  if (cached && cached.expiresAt > Date.now()) return cached.stamp;
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { tokensValidFrom: true },
  });
  const stamp = user?.tokensValidFrom ?? null;
  tokensValidFromCache.set(userId, {
    stamp,
    expiresAt: Date.now() + TOKENS_VALID_CACHE_TTL_MS,
  });
  return stamp;
}

export function bumpTokensValidFromCache(userId: number, stamp: Date): void {
  tokensValidFromCache.set(userId, {
    stamp,
    expiresAt: Date.now() + TOKENS_VALID_CACHE_TTL_MS,
  });
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

  // Enforce `tokensValidFrom`. Lets password-change and logout-all
  // invalidate every previously-issued access token even before its
  // 15-minute TTL expires. The DB lookup is cached for 60s.
  if (typeof payload.iat === 'number') {
    const floor = await getTokensValidFrom(payload.sub);
    if (floor) {
      const iatMs = payload.iat * 1000;
      if (iatMs < floor.getTime()) {
        res.status(401).json({ error: 'Token expired or invalid' });
        return;
      }
    }
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
