import { randomUUID } from 'crypto';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import prisma from '../../infra/db/prisma.js';
import { JWT_ACCESS_SECRET as ACCESS_SECRET } from '../../shared/authSecrets.js';
import { resolveMembershipForUser } from '../../shared/http/requireAuth.js';
import { hasRight, POS_OVERRIDE_RIGHT } from '../../shared/http/permissions.js';

const OVERRIDE_TTL_SECONDS = 120;
const PURPOSE = 'pos-override';

export interface OverrideGrant {
  token: string;
  authorizerName: string;
}

export type OverrideOp =
  | 'setLineDiscount'
  | 'setUnitPrice'
  | 'setHeaderDiscount'
  | 'void'
  | 'return';

interface OverrideClaims {
  purpose?: string;
  shopId?: number;
  saleId?: number;
  op?: string;
  by?: number;
  byName?: string;
  jti?: string;
  exp?: number;
}

export async function authorizeOverride(
  shopId: number,
  email: string,
  password: string,
  saleId: number,
  op: OverrideOp,
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

  const token = jwt.sign(
    { purpose: PURPOSE, shopId, saleId, op, by: user.id, byName: user.name, jti: randomUUID() },
    ACCESS_SECRET,
    { algorithm: 'HS256', expiresIn: OVERRIDE_TTL_SECONDS },
  );
  return { token, authorizerName: user.name };
}

export async function verifyOverride(
  token: string | undefined,
  shopId: number,
  saleId: number,
  op: OverrideOp,
): Promise<{ by: number; byName: string } | null> {
  if (!token) return null;
  let p: OverrideClaims;
  try {
    p = jwt.verify(token, ACCESS_SECRET, { algorithms: ['HS256'] }) as OverrideClaims;
  } catch {
    return null;
  }
  if (
    p.purpose !== PURPOSE ||
    p.shopId !== shopId ||
    p.saleId !== saleId ||
    p.op !== op ||
    typeof p.by !== 'number' ||
    typeof p.jti !== 'string'
  ) {
    return null;
  }

  const expiresAt = p.exp ? new Date(p.exp * 1000) : new Date(Date.now() + OVERRIDE_TTL_SECONDS * 1000);
  try {
    await prisma.posOverrideGrant.create({
      data: { jti: p.jti, shopId, saleId, op, authorizedById: p.by, expiresAt },
    });
  } catch (e) {
    if ((e as { code?: string }).code === 'P2002') return null;
    throw e;
  }

  void prisma.posOverrideGrant
    .deleteMany({ where: { expiresAt: { lt: new Date() } } })
    .catch(() => undefined);

  return { by: p.by, byName: p.byName ?? '' };
}
