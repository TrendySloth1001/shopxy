import { randomUUID } from 'crypto';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import prisma from '../../infra/db/prisma.js';
import { JWT_ACCESS_SECRET as ACCESS_SECRET } from '../../shared/authSecrets.js';
import { resolveMembershipForUser } from '../../shared/http/requireAuth.js';
import { hasRight, POS_OVERRIDE_RIGHT } from '../../shared/http/permissions.js';

/// Manager-approval for privileged till actions (discounts, price overrides,
/// voids, returns). A cashier who lacks `invoices:override` gets a manager/owner
/// to authorise IN PERSON via their credentials; the server returns a short-lived
/// signed grant the cashier's client replays on the one action.
///
/// CASH-2 — the grant is SINGLE-USE and ACTION-BOUND. At mint time we bake into
/// the JWT a random `jti`, the target `saleId`, and the `op` it authorises. On
/// the first successful replay we INSERT the jti into `pos_override_grants`; the
/// unique constraint makes the burn atomic, so a replayed grant (same jti) — or
/// the same grant aimed at a different sale/op — is rejected. We deliberately use
/// a DB row, not Redis, because the single-use guard must NOT degrade open on a
/// cache outage (that would re-open the replay hole).

const OVERRIDE_TTL_SECONDS = 120; // 2m
const PURPOSE = 'pos-override';

export interface OverrideGrant {
  token: string;
  authorizerName: string;
}

/// The privileged till ops a grant can authorise. Binding to one op stops a
/// grant minted for (say) a line discount from being replayed to void a sale.
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

/// Verify a manager's credentials + privilege and mint a grant BOUND to one
/// shop + saleId + op. The authorizer must be an active member of THIS shop
/// holding the override right (Owner bypasses). Failure messages are
/// deliberately coarse (no step leakage).
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

/// Verify AND burn a replayed grant for this shop + saleId + op. Returns the
/// authorizer, or null if the token is missing/invalid/expired, for another
/// shop/sale/op, or has already been used (reuse → null). Single-use is enforced
/// by inserting the jti under a unique constraint: a duplicate insert (P2002)
/// means the grant was already consumed, so we reject.
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

  // Burn the grant: the unique jti makes this the single-use gate. A duplicate
  // (already consumed) throws P2002 → reject. The row's TTL mirrors the JWT exp
  // so the table stays small (swept opportunistically below).
  const expiresAt = p.exp ? new Date(p.exp * 1000) : new Date(Date.now() + OVERRIDE_TTL_SECONDS * 1000);
  try {
    await prisma.posOverrideGrant.create({
      data: { jti: p.jti, shopId, saleId, op, authorizedById: p.by, expiresAt },
    });
  } catch (e) {
    if ((e as { code?: string }).code === 'P2002') return null; // already used → reuse rejected
    throw e;
  }

  // Opportunistic sweep of expired rows (cheap; keeps the ledger bounded without
  // a dedicated cron). Best-effort — never blocks the authorisation.
  void prisma.posOverrideGrant
    .deleteMany({ where: { expiresAt: { lt: new Date() } } })
    .catch(() => undefined);

  return { by: p.by, byName: p.byName ?? '' };
}
