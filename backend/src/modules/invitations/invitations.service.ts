import crypto from 'crypto';
import prisma from '../../infra/db/prisma.js';
import type { Prisma, PrismaClient } from '@prisma/client';

const INVITE_TTL_DAYS = 14;

export type LinkType = 'PARTY' | 'VENDOR';
export type InviteStatus = 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED';

/// Thrown inside `respond({ decision: 'ACCEPT' })` when the target
/// Party/Vendor row is already linked to someone else (or was claimed
/// by a sibling invitation between the PENDING check and the link
/// claim). The transaction wrapper catches this and converts it into a
/// `PARTY_ALREADY_LINKED` error so the FE can surface a clear message.
class InvitationAlreadyLinkedError extends Error {
  constructor() {
    super('PARTY_ALREADY_LINKED');
    this.name = 'InvitationAlreadyLinkedError';
  }
}

const inviteSelect = {
  id: true,
  shopId: true,
  fromUserId: true,
  toEmail: true,
  toUserId: true,
  linkType: true,
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
  fromUser: { select: { id: true, name: true, email: true } },
  party: { select: { id: true, name: true, email: true } },
  vendor: { select: { id: true, name: true, email: true } },
} satisfies Prisma.InvitationSelect;

export type InvitationDTO = Prisma.InvitationGetPayload<{ select: typeof inviteSelect }>;

export class InvitationsService {
  /// Owner sends an invitation. Two modes:
  ///   1. **Existing contact** — partyId / vendorId is passed; the row
  ///      is validated and the FK is stored on the invitation.
  ///   2. **Bare email** — neither id is passed; `displayName` becomes
  ///      the contact's name and the actual Party/Vendor row is created
  ///      lazily at accept time. Cuts a step out of the merchant flow.
  async sendInvite(input: {
    shopId: number;
    fromUserId: number;
    toEmail: string;
    linkType: LinkType;
    partyId?: number | null;
    vendorId?: number | null;
    displayName?: string | null;
    message?: string | null;
  }) {
    const toEmail = input.toEmail.toLowerCase().trim();
    const { linkType } = input;
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

    // Fetch sender + the linked entity + recipient user + duplicate
    // check in parallel. Entity look-ups only run for the existing-
    // contact path.
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
      // Duplicate guard: a pending invite for the same (sender, email,
      // linkType, entity). The partial unique indexes catch the entity
      // case at the DB level; this guard catches the bare-email case
      // and gives a cleaner error than a UNIQUE violation.
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

  /// Inbox — invitations addressed to the current user. Filtered by
  /// status, paginated, ordered newest-first. Uses the
  /// (toUserId, status, createdAt DESC) compound index.
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

  /// Current user accepts an invitation addressed to them. Links the
  /// party/vendor row to their user id and notifies the sender — all in
  /// one transaction so partial state is impossible.
  async respond(opts: {
    invitationId: number;
    userId: number;
    decision: 'ACCEPT' | 'DECLINE';
  }) {
    try {
      return await prisma.$transaction(async (tx) => {
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
        return { error: 'Invitation expired' as const };
      }

      const newStatus = opts.decision === 'ACCEPT' ? 'ACCEPTED' : 'DECLINED';
      const respondedAt = new Date();

      // Race guard: two concurrent accepts could both pass the PENDING
      // check above before either commits. Atomically flip status here
      // and bail if someone else won. The party/vendor linking + status
      // finalisation below is then guaranteed to run for exactly one
      // accept.
      const claimed = await tx.invitation.updateMany({
        where: { id: invite.id, status: 'PENDING' },
        data: { status: newStatus, respondedAt },
      });
      if (claimed.count === 0) {
        return { error: 'Already responded' as const };
      }

      // ── On ACCEPT: link or lazy-create the party/vendor row. We do
      // this BEFORE the invitation.update so we can stamp the new FK
      // back onto the invitation in a single write.
      let newPartyId: number | null = invite.partyId;
      let newVendorId: number | null = invite.vendorId;

      if (opts.decision === 'ACCEPT') {
        if (invite.linkType === 'PARTY') {
          if (invite.partyId) {
            // Atomic claim of the Party row. updateMany returns count=0
            // when the row already has linkedUserId set (to anyone —
            // including this same user from a duplicate accept). We
            // MUST treat that as a real failure and back the invitation
            // status out, else the customer sees "accepted" but no
            // ledger access is created.
            const linked = await tx.party.updateMany({
              where: { id: invite.partyId, linkedUserId: null },
              data: { linkedUserId: opts.userId },
            });
            if (linked.count === 0) {
              // Was it already linked to THIS user (replayed accept)?
              const existing = await tx.party.findUnique({
                where: { id: invite.partyId },
                select: { linkedUserId: true },
              });
              if (existing?.linkedUserId !== opts.userId) {
                throw new InvitationAlreadyLinkedError();
              }
            }
          } else {
            // Bare-email invite — materialise the party at accept time.
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
        }
      }

      // Status + respondedAt were already set by the updateMany race
      // guard above; here we only stamp the (possibly newly-materialised)
      // partyId/vendorId back onto the invitation row.
      const updated = await tx.invitation.update({
        where: { id: invite.id },
        data: {
          partyId: newPartyId,
          vendorId: newVendorId,
        },
        select: inviteSelect,
      });

      // Notify the sender. Use the *updated* invitation so the data
      // payload points at the lazily-created party/vendor id, not the
      // null snapshot from before the accept.
      await tx.notification.create({
        data: {
          userId: invite.fromUserId,
          kind: opts.decision === 'ACCEPT' ? 'INVITE_ACCEPTED' : 'INVITE_DECLINED',
          title:
            opts.decision === 'ACCEPT'
              ? `${invite.toEmail} accepted your invitation`
              : `${invite.toEmail} declined your invitation`,
          body: invite.displayName
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
    } catch (e) {
      if (e instanceof InvitationAlreadyLinkedError) {
        return { error: 'PARTY_ALREADY_LINKED' as const };
      }
      throw e;
    }
  }

  /// Sender cancels an invitation they previously sent. Notifies the
  /// recipient if a user account exists.
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

  /// Called on registration: take all PENDING invites addressed to the
  /// user's email (where toUserId is null) and link them to the new
  /// account, then fan out notifications. Single transaction.
  async claimPendingForNewUser(opts: { userId: number; email: string }) {
    const email = opts.email.toLowerCase().trim();
    return prisma.$transaction(async (tx) => {
      // 1) attach the new userId — covered by (toEmail, status) index.
      await tx.invitation.updateMany({
        where: { toEmail: email, toUserId: null, status: 'PENDING' },
        data: { toUserId: opts.userId },
      });

      // 2) bulk-load just-claimed invitations so we can fan out notifs.
      const pending = await tx.invitation.findMany({
        where: { toUserId: opts.userId, status: 'PENDING' },
        select: {
          id: true,
          linkType: true,
          partyId: true,
          vendorId: true,
          fromShopName: true,
          displayName: true,
        },
      });

      if (pending.length > 0) {
        await tx.notification.createMany({
          data: pending.map((p) => ({
            userId: opts.userId,
            kind: 'INVITE_RECEIVED',
            title: `${p.fromShopName ?? 'A shop'} invited you`,
            body: p.displayName
              ? `As ${p.linkType === 'PARTY' ? 'party' : 'vendor'} "${p.displayName}"`
              : null,
            data: {
              invitationId: p.id,
              linkType: p.linkType,
              partyId: p.partyId,
              vendorId: p.vendorId,
            },
          })),
        });
      }

      return { claimed: pending.length };
    });
  }
}

/// Helper reused by claim + sendInvite — kept module-private so the
/// signature can stay tight.
async function createInviteReceivedNotification(
  tx: Prisma.TransactionClient | PrismaClient,
  opts: { userId: number; invitation: InvitationDTO },
) {
  const invite = opts.invitation;
  await tx.notification.create({
    data: {
      userId: opts.userId,
      kind: 'INVITE_RECEIVED',
      title: `${invite.fromShopName ?? 'A shop'} invited you`,
      body: invite.displayName
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

export const invitationsService = new InvitationsService();
