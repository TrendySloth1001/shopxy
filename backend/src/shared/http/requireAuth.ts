import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { Role, ShopRole } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { JWT_ACCESS_SECRET as ACCESS_SECRET } from '../authSecrets.js';
import { isSessionRevoked } from '../sessionRevocation.js';

export interface AuthPayload {
  sub: number;
  email: string;
  role: Role;
  isPlatformAdmin: boolean;
  shopId?: number;
  shopRole?: ShopRole;
  shopRoleName?: string | null;
  shopPermissions?: string[];
  iat?: number;
  sid?: string;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthPayload;
    }
  }
}

export interface Membership {
  shopId: number;
  shopRole: ShopRole;
  roleName: string | null;
  permissions: string[];
  version: number;
}
const membershipCache = new Map<number, { membership: Membership | undefined; expiresAt: number }>();
const CACHE_TTL_MS = 60_000;

export async function resolveMembershipForUser(
  userId: number,
): Promise<Membership | undefined> {
  const cached = membershipCache.get(userId);
  if (cached && cached.expiresAt > Date.now()) return cached.membership;
  const row = await prisma.shopMember.findUnique({
    where: { userId },
    select: {
      shopId: true,
      role: true,
      roleName: true,
      permissions: true,
      updatedAt: true,
    },
  });
  const membership: Membership | undefined = row
    ? {
        shopId: row.shopId,
        shopRole: row.role,
        roleName: row.roleName,
        permissions: row.permissions,
        version: row.updatedAt.getTime(),
      }
    : undefined;
  membershipCache.set(userId, { membership, expiresAt: Date.now() + CACHE_TTL_MS });
  return membership;
}

interface UserSecurity {
  tokensValidFrom: Date | null;
  role: Role;
  isPlatformAdmin: boolean;
  isActive: boolean;
}
const userSecurityCache = new Map<number, { value: UserSecurity; expiresAt: number }>();
const TOKENS_VALID_CACHE_TTL_MS = 60_000;

async function getUserSecurity(userId: number): Promise<UserSecurity | null> {
  const cached = userSecurityCache.get(userId);
  if (cached && cached.expiresAt > Date.now()) return cached.value;
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { tokensValidFrom: true, role: true, isPlatformAdmin: true, isActive: true },
  });
  if (!user) return null;
  const value: UserSecurity = {
    tokensValidFrom: user.tokensValidFrom ?? null,
    role: user.role,
    isPlatformAdmin: user.isPlatformAdmin,
    isActive: user.isActive,
  };
  userSecurityCache.set(userId, { value, expiresAt: Date.now() + TOKENS_VALID_CACHE_TTL_MS });
  return value;
}

export function bumpTokensValidFromCache(userId: number, _stamp: Date): void {
  userSecurityCache.delete(userId);
}

export async function isPlatformAdminLive(userId: number): Promise<boolean> {
  const security = await getUserSecurity(userId);
  return !!security && security.isActive && security.isPlatformAdmin;
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

  const security = await getUserSecurity(payload.sub);
  if (!security || !security.isActive) {
    res.status(401).json({ error: 'Token expired or invalid' });
    return;
  }
  payload.role = security.role;
  payload.isPlatformAdmin = security.isPlatformAdmin;

  if (typeof payload.iat === 'number' && security.tokensValidFrom) {
    const iatMs = payload.iat * 1000;
    if (iatMs < security.tokensValidFrom.getTime()) {
      res.status(401).json({ error: 'Token expired or invalid' });
      return;
    }
  }

  if (payload.sid && isSessionRevoked(payload.sid)) {
    res.status(401).json({ error: 'Token expired or invalid' });
    return;
  }

  if (payload.role === 'OWNER') {
    const membership = await resolveMembershipForUser(payload.sub);
    payload.shopId = membership?.shopId;
    payload.shopRole = membership?.shopRole;
    payload.shopRoleName = membership?.roleName ?? null;
    payload.shopPermissions = membership?.permissions ?? [];
    if (membership) {
      res.setHeader('X-Shop-Perms', String(membership.version));
    }
  }

  req.user = payload;
  next();
}

export function invalidateMembershipCache(userId: number): void {
  membershipCache.delete(userId);
}

export const invalidateShopIdCache = invalidateMembershipCache;
