import crypto from 'crypto';
import prisma from '../../infra/db/prisma.js';
import type { Prisma, PrismaClient, ShopRole } from '@prisma/client';
import {
  bumpTokensValidFromCache,
  invalidateMembershipCache,
} from '../../shared/http/requireAuth.js';
import { normalizeRights } from '../../shared/http/permissions.js';
import { rightsBeyondActor } from '../team/team.service.js';

const INVITE_TTL_DAYS = 14;

export type LinkType = 'PARTY' | 'VENDOR' | 'TEAM';
export type InviteStatus = 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED';

class InvitationAlreadyLinkedError extends Error {
  constructor() {
    super('PARTY_ALREADY_LINKED');
    this.name = 'InvitationAlreadyLinkedError';
  }
}

class TeamInviteError extends Error {
  constructor(public code: string) {
    super(code);
    this.name = 'TeamInviteError';
  }
}

const inviteSelect = {
  id: true,
  shopId: true,
  fromUserId: true,
  toEmail: true,
  toUserId: true,
  linkType: true,
  teamRole: true,
  teamRoleName: true,
  teamPermissions: true,
  partyId: true,
  vendorId: true,
  status: true,
  message: true,
  fromShopName: true,
  displayName: true,
  expiresAt: true,
  respondedAt: true,
  createdAt: true,
  updatedAt: true,
  fromUser: { select: { id: true, name: true, email: true, avatarUrl: true } },
  shop: {
    select: {
      id: true,
      name: true,
      slug: true,
      logoUrl: true,
      bannerUrl: true,
    },
  },
  party: { select: { id: true, name: true, email: true } },
  vendor: { select: { id: true, name: true, email: true } },
} satisfies Prisma.InvitationSelect;

export type InvitationDTO = Prisma.InvitationGetPayload<{ select: typeof inviteSelect }>;

export class InvitationsService {
  async sendInvite(input: {
    shopId: number;
    fromUserId: number;
    toEmail: string;
    linkType: LinkType;
    teamRoleName?: string | null;
    teamPermissions?: string[] | null;
    partyId?: number | null;
    vendorId?: number | null;
    displayName?: string | null;
    message?: string | null;
    actingShopRole?: ShopRole;
    actingPermissions?: string[];
  }) {
    const toEmail = input.toEmail.toLowerCase().trim();
    const { linkType } = input;

    if (linkType === 'TEAM') {
      return this.sendTeamInvite({
        shopId: input.shopId,
        fromUserId: input.fromUserId,
        toEmail,
        teamRoleName: input.teamRoleName ?? null,
        teamPermissions: input.teamPermissions ?? null,
        message: input.message ?? null,
        actingShopRole: input.actingShopRole,
        actingPermissions: input.actingPermissions,
      });
    }
    const hasEntity =
      (linkType === 'PARTY' && !!input.partyId) ||
      (linkType === 'VENDOR' && !!input.vendorId);
    const displayName = input.displayName?.trim() || null;

    if (!hasEntity && !displayName) {
      return {
        error:
          'Provide either an existing partyId/vendorId or a displayName' as const,
      };
    }

    const [fromUser, party, vendor, toUser, existing] = await Promise.all([
      prisma.user.findUnique({
        where: { id: input.fromUserId },
        select: { id: true, name: true, email: true },
      }),
      hasEntity && linkType === 'PARTY' && input.partyId
        ? prisma.party.findFirst({
            where: { id: input.partyId, shopId: input.shopId },
            select: { id: true, name: true, email: true, linkedUserId: true },
          })
        : Promise.resolve(null),
      hasEntity && linkType === 'VENDOR' && input.vendorId
        ? prisma.vendor.findFirst({
            where: { id: input.vendorId, shopId: input.shopId },
            select: { id: true, name: true, email: true, linkedUserId: true },
          })
        : Promise.resolve(null),
      prisma.user.findUnique({
        where: { email: toEmail },
        select: { id: true, name: true, email: true },
      }),
      prisma.invitation.findFirst({
        where: {
          fromUserId: input.fromUserId,
          toEmail,
          status: 'PENDING',
          linkType,
          ...(hasEntity
            ? linkType === 'PARTY'
              ? { partyId: input.partyId ?? undefined }
              : { vendorId: input.vendorId ?? undefined }
            : { partyId: null, vendorId: null }),
        },
        select: { id: true },
      }),
    ]);

    if (!fromUser) return { error: 'Sender not found' as const };
    if (hasEntity && linkType === 'PARTY' && !party)
      return { error: 'Party not found' as const };
    if (hasEntity && linkType === 'VENDOR' && !vendor)
      return { error: 'Vendor not found' as const };

    const entityLinkedUserId = hasEntity
      ? linkType === 'PARTY' ? party?.linkedUserId : vendor?.linkedUserId
      : null;
    if (entityLinkedUserId) {
      return { error: 'This contact is already linked to a Shopxy account' as const };
    }

    if (toUser && toUser.id === input.fromUserId) {
      return { error: "You can't invite your own account" as const };
    }
    if (existing) {
      return { error: 'A pending invitation already exists for this contact' as const };
    }

    const token = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + INVITE_TTL_DAYS * 24 * 60 * 60 * 1000);
    const finalDisplayName =
      displayName ?? (linkType === 'PARTY' ? party?.name : vendor?.name) ?? null;

    const invitation = await prisma.$transaction(async (tx) => {
      const created = await tx.invitation.create({
        data: {
          shopId: input.shopId,
          fromUserId: input.fromUserId,
          toEmail,
          toUserId: toUser?.id ?? null,
          linkType,
          partyId: hasEntity && linkType === 'PARTY' ? input.partyId ?? null : null,
          vendorId: hasEntity && linkType === 'VENDOR' ? input.vendorId ?? null : null,
          message: input.message?.trim() || null,
          fromShopName: fromUser.name,
          displayName: finalDisplayName,
          token,
          expiresAt,
        },
        select: inviteSelect,
      });

      if (toUser) {
        await createInviteReceivedNotification(tx, {
          userId: toUser.id,
          invitation: created,
        });
      }

      return created;
    });

    return { invitation };
  }

  private async sendTeamInvite(input: {
    shopId: number;
    fromUserId: number;
    toEmail: string;
    teamRoleName: string | null;
    teamPermissions: string[] | null;
    message: string | null;
    actingShopRole?: ShopRole;
    actingPermissions?: string[];
  }) {
    const { toEmail } = input;
    const teamRoleName = input.teamRoleName?.trim();
    if (!teamRoleName) {
      return { error: 'A role is required' as const };
    }
    const teamPermissions = normalizeRights(input.teamPermissions ?? []);

    if (
      rightsBeyondActor(input.actingShopRole, input.actingPermissions, teamPermissions)
        .length > 0
    ) {
      return { error: 'CANNOT_GRANT_BEYOND_OWN_RIGHTS' as const };
    }

    const [fromUser, toUser, existing] = await Promise.all([
      prisma.user.findUnique({
        where: { id: input.fromUserId },
        select: { id: true, name: true },
      }),
      prisma.user.findUnique({
        where: { email: toEmail },
        select: { id: true, role: true, shopMembership: { select: { shopId: true } } },
      }),
      prisma.invitation.findFirst({
        where: { shopId: input.shopId, toEmail, linkType: 'TEAM', status: 'PENDING' },
        select: { id: true },
      }),
    ]);

    if (!fromUser) return { error: 'Sender not found' as const };
    if (toUser) {
      if (toUser.id === input.fromUserId) {
        return { error: "You can't invite your own account" as const };
      }
      if (toUser.shopMembership) {
        return { error: 'This person is already on a shop team' as const };
      }
    }
    if (existing) {
      return { error: 'A pending invitation already exists for this person' as const };
    }

    const token = crypto.randomUUID();
    const expiresAt = new Date(Date.now() + INVITE_TTL_DAYS * 24 * 60 * 60 * 1000);

    const invitation = await prisma.$transaction(async (tx) => {
      const created = await tx.invitation.create({
        data: {
          shopId: input.shopId,
          fromUserId: input.fromUserId,
          toEmail,
          toUserId: toUser?.id ?? null,
          linkType: 'TEAM',
          teamRole: 'STAFF',
          teamRoleName,
          teamPermissions,
          message: input.message?.trim() || null,
          fromShopName: fromUser.name,
          displayName: null,
          token,
          expiresAt,
        },
        select: inviteSelect,
      });
      if (toUser) {
        await createInviteReceivedNotification(tx, {
          userId: toUser.id,
          invitation: created,
        });
      }
      return created;
    });

    return { invitation };
  }

  async listIncoming(opts: {
    userId: number;
    status?: InviteStatus | 'ALL';
    skip: number;
    limit: number;
  }) {
    const where: Prisma.InvitationWhereInput = { toUserId: opts.userId };
    if (opts.status && opts.status !== 'ALL') where.status = opts.status;

    const [data, total] = await Promise.all([
      prisma.invitation.findMany({
        where,
        select: inviteSelect,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.invitation.count({ where }),
    ]);
    return { data, total };
  }

  async listOutgoing(opts: {
    userId: number;
    status?: InviteStatus | 'ALL';
    skip: number;
    limit: number;
  }) {
    const where: Prisma.InvitationWhereInput = { fromUserId: opts.userId };
    if (opts.status && opts.status !== 'ALL') where.status = opts.status;

    const [data, total] = await Promise.all([
      prisma.invitation.findMany({
        where,
        select: inviteSelect,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.invitation.count({ where }),
    ]);
    return { data, total };
  }

  async respond(opts: {
    invitationId: number;
    userId: number;
    decision: 'ACCEPT' | 'DECLINE';
  }) {
    try {
      const result = await prisma.$transaction(async (tx) => {
      const invite = await tx.invitation.findUnique({
        where: { id: opts.invitationId },
        select: inviteSelect,
      });
      if (!invite) return { error: 'Invitation not found' as const };
      if (invite.toUserId !== opts.userId) return { error: 'Not your invitation' as const };
      if (invite.status !== 'PENDING') return { error: 'Already responded' as const };
      if (invite.expiresAt < new Date()) {
        await tx.invitation.update({
          where: { id: invite.id },
          data: { status: 'EXPIRED' },
        });
        await notifyInviteExpired(tx, invite);
        return { error: 'Invitation expired' as const };
      }

      const newStatus = opts.decision === 'ACCEPT' ? 'ACCEPTED' : 'DECLINED';
      const respondedAt = new Date();

      const claimed = await tx.invitation.updateMany({
        where: { id: invite.id, status: 'PENDING' },
        data: { status: newStatus, respondedAt },
      });
      if (claimed.count === 0) {
        return { error: 'Already responded' as const };
      }

      let newPartyId: number | null = invite.partyId;
      let newVendorId: number | null = invite.vendorId;

      if (opts.decision === 'ACCEPT') {
        if (invite.linkType === 'PARTY') {
          if (invite.partyId) {
            const linked = await tx.party.updateMany({
              where: { id: invite.partyId, linkedUserId: null },
              data: { linkedUserId: opts.userId },
            });
            if (linked.count === 0) {
              const existing = await tx.party.findUnique({
                where: { id: invite.partyId },
                select: { linkedUserId: true },
              });
              if (existing?.linkedUserId !== opts.userId) {
                throw new InvitationAlreadyLinkedError();
              }
            }
          } else {
            const created = await tx.party.create({
              data: {
                shopId: invite.shopId,
                name: invite.displayName ?? invite.toEmail.split('@')[0],
                email: invite.toEmail,
                linkedUserId: opts.userId,
              },
              select: { id: true },
            });
            newPartyId = created.id;
          }
        } else if (invite.linkType === 'VENDOR') {
          if (invite.vendorId) {
            const linked = await tx.vendor.updateMany({
              where: { id: invite.vendorId, linkedUserId: null },
              data: { linkedUserId: opts.userId },
            });
            if (linked.count === 0) {
              const existing = await tx.vendor.findUnique({
                where: { id: invite.vendorId },
                select: { linkedUserId: true },
              });
              if (existing?.linkedUserId !== opts.userId) {
                throw new InvitationAlreadyLinkedError();
              }
            }
          } else {
            const created = await tx.vendor.create({
              data: {
                shopId: invite.shopId,
                name: invite.displayName ?? invite.toEmail.split('@')[0],
                email: invite.toEmail,
                linkedUserId: opts.userId,
              },
              select: { id: true },
            });
            newVendorId = created.id;
          }
        } else if (invite.linkType === 'TEAM') {
          if (!invite.teamRoleName) {
            throw new TeamInviteError('INVALID_TEAM_ROLE');
          }
          const acceptingUser = await tx.user.findUnique({
            where: { id: opts.userId },
            select: { role: true, shopMembership: { select: { id: true } } },
          });
          if (acceptingUser?.shopMembership) {
            throw new TeamInviteError('ALREADY_ON_TEAM');
          }
          await tx.shopMember.create({
            data: {
              shopId: invite.shopId,
              userId: opts.userId,
              role: 'STAFF',
              roleName: invite.teamRoleName,
              permissions: normalizeRights(invite.teamPermissions),
            },
          });
          await tx.user.update({
            where: { id: opts.userId },
            data: { role: 'OWNER', tokensValidFrom: respondedAt },
          });
        }
      }

      const updated = await tx.invitation.update({
        where: { id: invite.id },
        data: {
          partyId: newPartyId,
          vendorId: newVendorId,
        },
        select: inviteSelect,
      });

      await tx.notification.create({
        data: {
          userId: invite.fromUserId,
          kind: opts.decision === 'ACCEPT' ? 'INVITE_ACCEPTED' : 'INVITE_DECLINED',
          title:
            opts.decision === 'ACCEPT'
              ? `${invite.toEmail} accepted your invitation`
              : `${invite.toEmail} declined your invitation`,
          body:
            invite.linkType === 'TEAM'
              ? `Joined the team as ${invite.teamRoleName ?? 'staff'}`
              : invite.displayName
                ? `Linked as ${invite.linkType === 'PARTY' ? 'party' : 'vendor'} "${invite.displayName}"`
                : null,
          data: {
            invitationId: invite.id,
            linkType: invite.linkType,
            partyId: updated.partyId,
            vendorId: updated.vendorId,
          },
        },
      });

        return { invitation: updated };
      });

      const acceptedInvite = 'invitation' in result ? result.invitation : undefined;
      if (
        opts.decision === 'ACCEPT' &&
        acceptedInvite &&
        acceptedInvite.linkType === 'TEAM'
      ) {
        const stamp = acceptedInvite.respondedAt ?? new Date();
        bumpTokensValidFromCache(opts.userId, stamp);
        invalidateMembershipCache(opts.userId);
      }
      return result;
    } catch (e) {
      if (e instanceof InvitationAlreadyLinkedError) {
        return { error: 'PARTY_ALREADY_LINKED' as const };
      }
      if (e instanceof TeamInviteError) {
        return { error: e.code as 'ALREADY_ON_TEAM' | 'INVALID_TEAM_ROLE' };
      }
      throw e;
    }
  }

  async cancel(opts: { invitationId: number; userId: number }) {
    return prisma.$transaction(async (tx) => {
      const invite = await tx.invitation.findUnique({
        where: { id: opts.invitationId },
        select: inviteSelect,
      });
      if (!invite) return { error: 'Invitation not found' as const };
      if (invite.fromUserId !== opts.userId) return { error: 'Not your invitation' as const };
      if (invite.status !== 'PENDING') return { error: 'Already responded' as const };

      const updated = await tx.invitation.update({
        where: { id: invite.id },
        data: { status: 'CANCELLED', respondedAt: new Date() },
        select: inviteSelect,
      });

      if (invite.toUserId) {
        await tx.notification.create({
          data: {
            userId: invite.toUserId,
            kind: 'INVITE_CANCELLED',
            title: `${invite.fromShopName ?? 'A shop'} cancelled an invitation`,
            body: invite.displayName ?? null,
            data: { invitationId: invite.id },
          },
        });
      }

      return { invitation: updated };
    });
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async claimPendingForNewUser(_opts: { userId: number; email: string }) {
    return { claimed: 0 };
  }

  async claimByToken(opts: { userId: number; token: string }) {
    const token = opts.token.trim();
    if (!token) return { error: 'Invalid invitation token' as const };
    const invite = await prisma.invitation.findUnique({
      where: { token },
      select: {
        id: true,
        status: true,
        toUserId: true,
        expiresAt: true,
        fromUserId: true,
        toEmail: true,
        displayName: true,
        linkType: true,
      },
    });
    if (!invite) return { error: 'Invitation not found' as const };
    if (invite.toUserId !== null && invite.toUserId !== opts.userId) {
      return { error: 'This invitation belongs to someone else.' as const };
    }
    if (invite.status !== 'PENDING') return { error: 'This invitation has already been used.' as const };
    if (invite.expiresAt < new Date()) {
      const flipped = await prisma.invitation.updateMany({
        where: { id: invite.id, status: 'PENDING' },
        data: { status: 'EXPIRED' },
      });
      if (flipped.count > 0) await notifyInviteExpired(prisma, invite);
      return { error: 'This invitation has expired.' as const };
    }
    if (invite.toUserId === null) {
      const claimed = await prisma.invitation.updateMany({
        where: { id: invite.id, toUserId: null, status: 'PENDING' },
        data: { toUserId: opts.userId },
      });
      if (claimed.count === 0) return { error: 'This invitation belongs to someone else.' as const };
    }
    return { ok: true as const, invitationId: invite.id };
  }

  async expireStalePendingInvites(): Promise<{ expired: number }> {
    const stale = await prisma.invitation.findMany({
      where: { status: 'PENDING', expiresAt: { lt: new Date() } },
      select: { id: true },
    });
    if (stale.length === 0) return { expired: 0 };
    const ids = stale.map((s) => s.id);

    await prisma.invitation.updateMany({
      where: { id: { in: ids }, status: 'PENDING' },
      data: { status: 'EXPIRED' },
    });

    const justExpired = await prisma.invitation.findMany({
      where: { id: { in: ids }, status: 'EXPIRED' },
      select: {
        id: true,
        fromUserId: true,
        toEmail: true,
        displayName: true,
        linkType: true,
      },
    });
    for (const invite of justExpired) {
      await notifyInviteExpired(prisma, invite);
    }
    return { expired: justExpired.length };
  }
}

async function createInviteReceivedNotification(
  tx: Prisma.TransactionClient | PrismaClient,
  opts: { userId: number; invitation: InvitationDTO },
) {
  const invite = opts.invitation;
  await tx.notification.create({
    data: {
      userId: opts.userId,
      kind: 'INVITE_RECEIVED',
      title:
        invite.linkType === 'TEAM'
          ? `${invite.fromShopName ?? 'A shop'} invited you to their team`
          : `${invite.fromShopName ?? 'A shop'} invited you`,
      body:
        invite.linkType === 'TEAM'
          ? `As ${invite.teamRoleName ?? 'staff'}`
          : invite.displayName
            ? `As ${invite.linkType === 'PARTY' ? 'party' : 'vendor'} "${invite.displayName}"`
            : null,
      data: {
        invitationId: invite.id,
        linkType: invite.linkType,
        partyId: invite.partyId,
        vendorId: invite.vendorId,
      },
    },
  });
}

export async function notifyInviteExpired(
  db: Prisma.TransactionClient | PrismaClient,
  invite: {
    id: number;
    fromUserId: number;
    toEmail: string;
    displayName: string | null;
    linkType: string;
  },
): Promise<void> {
  await db.notification.create({
    data: {
      userId: invite.fromUserId,
      kind: 'INVITE_EXPIRED',
      title: `Your invitation to ${invite.toEmail} expired`,
      body: invite.displayName
        ? `No response for "${invite.displayName}" — you can send a new invite anytime.`
        : 'No response before the invite window closed — you can send a new invite anytime.',
      data: { invitationId: invite.id, linkType: invite.linkType },
    },
  });
}

export function teamRoleLabel(role: ShopRole | null | undefined): string {
  switch (role) {
    case 'OWNER':
      return 'owner';
    case 'MANAGER':
      return 'Manager';
    case 'STOCKIST':
      return 'Stockist';
    case 'CASHIER':
      return 'Cashier';
    default:
      return 'team member';
  }
}

export const invitationsService = new InvitationsService();
