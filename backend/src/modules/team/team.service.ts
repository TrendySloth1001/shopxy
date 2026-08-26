import { Prisma, ShopRole } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import {
  bumpTokensValidFromCache,
  invalidateMembershipCache,
} from '../../shared/http/requireAuth.js';
import { normalizeRights, presetFor } from '../../shared/http/permissions.js';

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

export const DEFAULT_ROLES: { name: string; permissions: string[] }[] = [
  { name: 'Manager', permissions: presetFor('MANAGER') },
  { name: 'Stockist', permissions: presetFor('STOCKIST') },
  { name: 'Cashier', permissions: presetFor('CASHIER') },
];

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
  async listMembers(shopId: number) {
    const members = await prisma.shopMember.findMany({
      where: { shopId },
      select: memberSelect,
      orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
    });
    return members.map((m) => ({ ...m, isOwner: m.role === 'OWNER' }));
  }

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
        token: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async listRoles(shopId: number) {
    const select = { id: true, name: true, permissions: true, builtin: true } as const;
    const orderBy = [{ builtin: 'desc' as const }, { name: 'asc' as const }];
    let roles = await prisma.teamRole.findMany({ where: { shopId }, select, orderBy });
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

  async deleteRole(opts: { shopId: number; id: number }) {
    const res = await prisma.teamRole.deleteMany({
      where: { id: opts.id, shopId: opts.shopId },
    });
    if (res.count === 0) return { error: 'ROLE_NOT_FOUND' as const };
    return { ok: true as const };
  }

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
