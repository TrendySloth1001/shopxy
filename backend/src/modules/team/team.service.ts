import { Prisma, ShopRole } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import {
  bumpTokensValidFromCache,
  invalidateMembershipCache,
} from '../../shared/http/requireAuth.js';
import { normalizeRights, presetFor } from '../../shared/http/permissions.js';

/// Delegation cap (TEAM-1): a non-owner with `team:manage` must not be
/// able to grant rights they don't themselves hold (which would let a
/// limited staffer escalate a colleague — or, by cross-granting, bypass
/// the own-role guard). OWNER bypasses every gate, so it can grant
/// anything. Returns the requested rights the actor lacks (empty = ok).
export function rightsBeyondActor(
  actorRole: ShopRole | undefined,
  actorPermissions: string[] | undefined,
  requested: string[],
): string[] {
  if (actorRole === 'OWNER') return [];
  const held = new Set(normalizeRights(actorPermissions ?? []));
  return normalizeRights(requested).filter((r) => !held.has(r));
}

const memberSelect = {
  id: true,
  role: true,
  roleName: true,
  permissions: true,
  createdAt: true,
  user: {
    select: { id: true, name: true, email: true, avatarUrl: true },
  },
} satisfies Prisma.ShopMemberSelect;

export type MemberDTO = Prisma.ShopMemberGetPayload<{ select: typeof memberSelect }>;

/// The starter roles seeded into every new shop (editable thereafter).
/// Names + permission sets mirror the classic presets.
export const DEFAULT_ROLES: { name: string; permissions: string[] }[] = [
  { name: 'Manager', permissions: presetFor('MANAGER') },
  { name: 'Stockist', permissions: presetFor('STOCKIST') },
  { name: 'Cashier', permissions: presetFor('CASHIER') },
];

/// Seed a shop's starter roles. Idempotent (skips duplicates) so it's
/// safe to call on every shop creation. `client` may be a tx.
export async function seedDefaultRoles(
  client: Prisma.TransactionClient | typeof prisma,
  shopId: number,
): Promise<void> {
  await client.teamRole.createMany({
    data: DEFAULT_ROLES.map((r) => ({
      shopId,
      name: r.name,
      permissions: r.permissions,
      builtin: true,
    })),
    skipDuplicates: true,
  });
}

export function isValidRoleName(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0 && value.trim().length <= 60;
}

export class TeamService {
  /// All members of a shop, owner first then by join order.
  async listMembers(shopId: number) {
    const members = await prisma.shopMember.findMany({
      where: { shopId },
      select: memberSelect,
      orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
    });
    return members.map((m) => ({ ...m, isOwner: m.role === 'OWNER' }));
  }

  /// Pending TEAM invitations for the shop.
  async listInvites(shopId: number) {
    return prisma.invitation.findMany({
      where: { shopId, linkType: 'TEAM', status: 'PENDING' },
      select: {
        id: true,
        toEmail: true,
        teamRoleName: true,
        teamPermissions: true,
        createdAt: true,
        expiresAt: true,
        // The single-use accept-invite token, so the owner can copy a
        // shareable link for a new hire who has no account yet (there's
        // no email delivery — the link is the delivery mechanism). Safe
        // to expose: this list is scoped to the owner's own shop and the
        // token only works for the invited email.
        token: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ── Roles (owner-defined, per-shop) ───────────────────────────────

  async listRoles(shopId: number) {
    const select = { id: true, name: true, permissions: true, builtin: true } as const;
    const orderBy = [{ builtin: 'desc' as const }, { name: 'asc' as const }];
    let roles = await prisma.teamRole.findMany({ where: { shopId }, select, orderBy });
    // Self-heal: a shop with no roles (created before seeding, or a failed seed)
    // would leave the invite picker without Manager/Stockist/Cashier presets.
    if (roles.length === 0) {
      await seedDefaultRoles(prisma, shopId);
      roles = await prisma.teamRole.findMany({ where: { shopId }, select, orderBy });
    }
    return roles;
  }

  async createRole(opts: {
    shopId: number;
    name: string;
    permissions: string[];
    actingShopRole?: ShopRole;
    actingPermissions?: string[];
  }) {
    if (!isValidRoleName(opts.name)) return { error: 'INVALID_ROLE_NAME' as const };
    if (rightsBeyondActor(opts.actingShopRole, opts.actingPermissions, opts.permissions).length > 0) {
      return { error: 'CANNOT_GRANT_BEYOND_OWN_RIGHTS' as const };
    }
    try {
      const role = await prisma.teamRole.create({
        data: {
          shopId: opts.shopId,
          name: opts.name.trim(),
          permissions: normalizeRights(opts.permissions),
          builtin: false,
        },
        select: { id: true, name: true, permissions: true, builtin: true },
      });
      return { role };
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return { error: 'ROLE_EXISTS' as const };
      }
      throw e;
    }
  }

  async updateRole(opts: {
    shopId: number;
    id: number;
    name?: string;
    permissions?: string[];
    actingShopRole?: ShopRole;
    actingPermissions?: string[];
  }) {
    if (opts.name !== undefined && !isValidRoleName(opts.name)) {
      return { error: 'INVALID_ROLE_NAME' as const };
    }
    if (
      opts.permissions !== undefined &&
      rightsBeyondActor(opts.actingShopRole, opts.actingPermissions, opts.permissions).length > 0
    ) {
      return { error: 'CANNOT_GRANT_BEYOND_OWN_RIGHTS' as const };
    }
    const existing = await prisma.teamRole.findFirst({
      where: { id: opts.id, shopId: opts.shopId },
      select: { id: true },
    });
    if (!existing) return { error: 'ROLE_NOT_FOUND' as const };
    try {
      const role = await prisma.teamRole.update({
        where: { id: existing.id },
        data: {
          ...(opts.name !== undefined ? { name: opts.name.trim() } : {}),
          ...(opts.permissions !== undefined
            ? { permissions: normalizeRights(opts.permissions) }
            : {}),
        },
        select: { id: true, name: true, permissions: true, builtin: true },
      });
      return { role };
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        return { error: 'ROLE_EXISTS' as const };
      }
      throw e;
    }
  }

  /// Delete a role template. Members who were assigned it keep their
  /// copied permissions — only the template (a future-assignment preset)
  /// goes away.
  async deleteRole(opts: { shopId: number; id: number }) {
    const res = await prisma.teamRole.deleteMany({
      where: { id: opts.id, shopId: opts.shopId },
    });
    if (res.count === 0) return { error: 'ROLE_NOT_FOUND' as const };
    return { ok: true as const };
  }

  // ── Assignment ────────────────────────────────────────────────────

  /// Set a member's role label + exact granted rights (the single
  /// assignment path used by the permission editor). Stores role=STAFF +
  /// the human label + the normalised grant. Takes effect on the
  /// member's next request via cache invalidation — no re-login.
  async setPermissions(opts: {
    shopId: number;
    actingUserId: number;
    actingShopRole?: ShopRole;
    actingPermissions?: string[];
    targetUserId: number;
    roleName: string;
    permissions: string[];
  }) {
    if (!isValidRoleName(opts.roleName)) {
      return { error: 'INVALID_ROLE_NAME' as const };
    }
    if (opts.targetUserId === opts.actingUserId) {
      return { error: 'CANNOT_CHANGE_OWN_ROLE' as const };
    }
    // Capped delegation (TEAM-1): can't grant a right the actor lacks.
    if (rightsBeyondActor(opts.actingShopRole, opts.actingPermissions, opts.permissions).length > 0) {
      return { error: 'CANNOT_GRANT_BEYOND_OWN_RIGHTS' as const };
    }
    const member = await prisma.shopMember.findUnique({
      where: { shopId_userId: { shopId: opts.shopId, userId: opts.targetUserId } },
      select: { id: true, role: true },
    });
    if (!member) return { error: 'MEMBER_NOT_FOUND' as const };
    if (member.role === 'OWNER') return { error: 'CANNOT_MODIFY_OWNER' as const };

    const updated = await prisma.shopMember.update({
      where: { id: member.id },
      data: {
        role: 'STAFF',
        roleName: opts.roleName.trim(),
        permissions: normalizeRights(opts.permissions),
      },
      select: memberSelect,
    });
    invalidateMembershipCache(opts.targetUserId);
    return { member: { ...updated, isOwner: false } };
  }

  /// Remove a staffer from the team. Can't remove the owner or yourself.
  /// Deletes their membership, drops the account back to CUSTOMER, and
  /// revokes their sessions immediately.
  async removeMember(opts: {
    shopId: number;
    actingUserId: number;
    targetUserId: number;
  }) {
    if (opts.targetUserId === opts.actingUserId) {
      return { error: 'CANNOT_REMOVE_SELF' as const };
    }
    const member = await prisma.shopMember.findUnique({
      where: { shopId_userId: { shopId: opts.shopId, userId: opts.targetUserId } },
      select: { id: true, role: true },
    });
    if (!member) return { error: 'MEMBER_NOT_FOUND' as const };
    if (member.role === 'OWNER') return { error: 'CANNOT_REMOVE_OWNER' as const };

    // Remove only their team access. We deliberately DON'T flip the
    // account to CUSTOMER — an account is only a "shopper" if it
    // registered on the customer app. A removed staffer stays a
    // merchant-side account with no shop, so they can still sign in and
    // land on the "No shop linked" screen (or accept a re-invite) rather
    // than being locked out of the merchant app. We do revoke their
    // sessions so their shop access ends immediately.
    const stamp = new Date();
    await prisma.$transaction([
      prisma.shopMember.delete({ where: { id: member.id } }),
      prisma.user.update({
        where: { id: opts.targetUserId },
        data: { tokensValidFrom: stamp },
      }),
      prisma.refreshToken.deleteMany({ where: { userId: opts.targetUserId } }),
    ]);
    bumpTokensValidFromCache(opts.targetUserId, stamp);
    invalidateMembershipCache(opts.targetUserId);
    return { ok: true as const };
  }
}

export const teamService = new TeamService();
