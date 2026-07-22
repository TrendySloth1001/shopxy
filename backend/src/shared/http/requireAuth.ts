import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { Role, ShopRole } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { JWT_ACCESS_SECRET as ACCESS_SECRET } from '../authSecrets.js';
import { isSessionRevoked } from '../sessionRevocation.js';

/// JWT payload as signed at login / refresh. `shopId` is included for
/// merchant accounts so per-request DB lookup is avoided; for customer
/// accounts it stays undefined.
export interface AuthPayload {
  sub: number;
  email: string;
  role: Role;
  isPlatformAdmin: boolean;
  /// Multi-tenant scope. Set for merchant accounts that belong to a
  /// shop's team (the owner, or invited staff). Resolved from the
  /// caller's ShopMember row. Undefined for CUSTOMER accounts and for
  /// merchant accounts that aren't on any team yet (a corner case).
  shopId?: number;
  /// The caller's position within `shopId`'s team. The preset label;
  /// the actual grant is `shopPermissions`. OWNER bypasses every gate.
  shopRole?: ShopRole;
  /// Human label of the caller's role (a TeamRole name) for display.
  shopRoleName?: string | null;
  /// The caller's granted rights as "<area>:<action>" strings. Source of
  /// truth for requireArea. Resolved (cached) from their ShopMember row;
  /// not baked into the JWT so a permission change takes effect within
  /// the cache TTL without re-issuing the token.
  shopPermissions?: string[];
  /// Standard JWT issued-at (seconds). Always present on tokens minted
  /// by this server; declared optional so older tokens (if any) parse
  /// without breaking. Used to compare against `User.tokensValidFrom`.
  iat?: number;
  /// Session id — the access token's refresh-token *family*. Lets a
  /// single-device logout revoke just this session's access token via
  /// the session-revocation set. Optional so pre-`sid` tokens still parse.
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


/// Tiny in-process cache so we don't re-query `ShopMember` for every
/// request when a JWT lacks `shopId`/`shopRole` (old tokens, or a member
/// whose role just changed). 60s is short enough that a brand-new shop
/// — or a role change / removal — takes effect quickly without forcing
/// logout/re-login.
export interface Membership {
  shopId: number;
  shopRole: ShopRole;
  roleName: string | null;
  permissions: string[];
  /// Monotonic version of this membership — the row's updatedAt epoch.
  /// Bumps whenever role/permissions change, so the client can detect a
  /// change from a response header and re-sync (see X-Shop-Perms).
  version: number;
}
const membershipCache = new Map<number, { membership: Membership | undefined; expiresAt: number }>();
const CACHE_TTL_MS = 60_000;

/// Resolve the caller's shop membership (shopId + role + granted rights)
/// from their single ShopMember row. `@@unique(userId)` guarantees at
/// most one, so this is a cheap indexed lookup. Cached for [CACHE_TTL_MS].
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

/// Per-user security snapshot cache. The requireAuth hot path can't
/// afford a SELECT-per-request; this caches the `tokensValidFrom` floor
/// **plus the live `role`/`isPlatformAdmin`/`isActive`** for a minute.
/// Re-reading the privilege flags here (rather than trusting the 15-min
/// JWT claims) means a demoted platform-admin or deactivated account
/// loses access within the TTL without waiting for token expiry, and
/// without needing a `tokensValidFrom` bump on every privilege change
/// (B-AUTH-3). Bumped via [bumpTokensValidFromCache] at password-change
/// / logout-all time so the next request picks up the new floor at once.
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

/// Force the next request to re-read this user's security snapshot. Used
/// by password-change / logout-all so the bumped `tokensValidFrom` floor
/// (and any role/admin change) takes effect immediately, not after TTL.
export function bumpTokensValidFromCache(userId: number, _stamp: Date): void {
  userSecurityCache.delete(userId);
}

/// Live (cached) platform-admin flag for a user. Lets privileged gates on
/// `optionalAuth` mounts (e.g. category writes) confirm the flag against
/// the DB instead of trusting a possibly-stale JWT claim (B-AUTH-4). On a
/// `requireAuth` route the snapshot is already warm from this same request.
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

  // Re-read the live security snapshot (role / isPlatformAdmin / isActive
  // / tokensValidFrom) instead of trusting the 15-min JWT claims. A
  // demoted admin, a flipped role, or a deactivated account is rejected
  // within the cache TTL — the JWT's stale privilege bits never apply
  // (B-AUTH-3). Cached for 60s; one indexed PK lookup on miss.
  const security = await getUserSecurity(payload.sub);
  if (!security || !security.isActive) {
    res.status(401).json({ error: 'Token expired or invalid' });
    return;
  }
  payload.role = security.role;
  payload.isPlatformAdmin = security.isPlatformAdmin;

  // Enforce `tokensValidFrom`. Lets password-change and logout-all
  // invalidate every previously-issued access token even before its
  // 15-minute TTL expires.
  if (typeof payload.iat === 'number' && security.tokensValidFrom) {
    const iatMs = payload.iat * 1000;
    if (iatMs < security.tokensValidFrom.getTime()) {
      res.status(401).json({ error: 'Token expired or invalid' });
      return;
    }
  }

  // Instant per-session logout: reject a token whose session was revoked by a
  // single-device logout, before its TTL runs out. In-memory O(1) check.
  if (payload.sid && isSessionRevoked(payload.sid)) {
    res.status(401).json({ error: 'Token expired or invalid' });
    return;
  }

  // Hydrate shopId + shopRole from the cache/DB. shopPermissions aren't
  // carried in the JWT, so we read them (cached) every request; shopId/
  // shopRole are confirmed/refreshed from the same ShopMember row. Cheap:
  // indexed by the @unique(userId) constraint. Only merchant-side
  // accounts have a membership; CUSTOMER accounts skip the lookup.
  if (payload.role === 'OWNER') {
    const membership = await resolveMembershipForUser(payload.sub);
    payload.shopId = membership?.shopId;
    payload.shopRole = membership?.shopRole;
    payload.shopRoleName = membership?.roleName ?? null;
    payload.shopPermissions = membership?.permissions ?? [];
    // Stamp the membership version so the client can detect a perms/role
    // change from any authenticated response and re-sync without a
    // re-login (see ApiClient.onPermsVersion / AuthProvider).
    if (membership) {
      res.setHeader('X-Shop-Perms', String(membership.version));
    }
  }

  req.user = payload;
  next();
}

/// Force-invalidate the cached membership for a user. Called after a
/// Shop row is created, a member is added/removed, or a role changes,
/// so the next request sees the new value without waiting for the TTL.
export function invalidateMembershipCache(userId: number): void {
  membershipCache.delete(userId);
}

/// Back-compat alias for callers still importing the pre-team-roles
/// name (it only ever invalidated the shopId, which now lives on the
/// membership row).
export const invalidateShopIdCache = invalidateMembershipCache;
