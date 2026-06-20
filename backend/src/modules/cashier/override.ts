import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import prisma from '../../infra/db/prisma.js';
import { requireEnv } from '../../shared/env.js';
import { resolveMembershipForUser } from '../../shared/http/requireAuth.js';
import { hasRight, POS_OVERRIDE_RIGHT } from '../../shared/http/permissions.js';

/// Manager-approval for privileged till actions (discounts, price overrides,
/// voids, returns). A cashier who lacks `invoices:override` gets a manager/owner
/// to authorise IN PERSON via their credentials; the server returns a short-lived
/// signed grant the cashier's client replays on the one action. Stateless (JWT) —
/// no server-side session, survives multi-instance.

const ACCESS_SECRET = requireEnv('JWT_ACCESS_SECRET');
const OVERRIDE_TTL = '2m';
const PURPOSE = 'pos-override';

export interface OverrideGrant {
  token: string;
  authorizerName: string;
}

/// Verify a manager's credentials + privilege and mint a grant. The authorizer
/// must be an active member of THIS shop holding the override right (Owner
/// bypasses). Failure messages are deliberately coarse (no step leakage).
export async function authorizeOverride(
  shopId: number,
  email: string,
  password: string,
): Promise<OverrideGrant | { error: string }> {
  const user = await prisma.user.findFirst({
    where: { email: { equals: email.trim(), mode: 'insensitive' } },
    select: { id: true, name: true, passwordHash: true, isActive: true },
  });
  const ok = user?.passwordHash ? await bcrypt.compare(password, user.passwordHash) : false;
  if (!user || !ok || !user.isActive) return { error: 'Incorrect manager email or password' };

  const membership = await resolveMembershipForUser(user.id);
  const authorised =
    membership?.shopId === shopId &&
    (membership.shopRole === 'OWNER' ||
      hasRight(membership.shopRole, membership.permissions, POS_OVERRIDE_RIGHT));
  if (!authorised) return { error: 'That account cannot authorise till overrides for this shop' };

  const token = jwt.sign({ purpose: PURPOSE, shopId, by: user.id, byName: user.name }, ACCESS_SECRET, {
    algorithm: 'HS256',
    expiresIn: OVERRIDE_TTL,
  });
  return { token, authorizerName: user.name };
}

/// Verify a replayed grant for this shop. Returns the authorizer, or null if the
/// token is missing/invalid/expired/for-another-shop.
export function verifyOverride(token: string | undefined, shopId: number): { by: number; byName: string } | null {
  if (!token) return null;
  try {
    const p = jwt.verify(token, ACCESS_SECRET, { algorithms: ['HS256'] }) as {
      purpose?: string;
      shopId?: number;
      by?: number;
      byName?: string;
    };
    if (p.purpose !== PURPOSE || p.shopId !== shopId || typeof p.by !== 'number') return null;
    return { by: p.by, byName: p.byName ?? '' };
  } catch {
    return null;
  }
}
