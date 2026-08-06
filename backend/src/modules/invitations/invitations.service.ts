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

/// Thrown inside `respond({ decision: 'ACCEPT' })` for a TEAM invite
/// when the accepting account can't be made a member (already on a
/// team, or the invite lost its role). Rolls the transaction back so
/// the invitation doesn't get stranded in ACCEPTED with no membership.
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
  // Shop branding for the customer-side invite card — logo + banner
  // render the inviting shop visually so the card is recognisable at a
  // glance, not just a string of text.
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
    teamRoleName?: string | null;
    teamPermissions?: string[] | null;
    partyId?: number | null;
    vendorId?: number | null;
    displayName?: string | null;
    message?: string | null;
    // Acting member's role + held rights, used to clamp TEAM grants to the
    // inviter's own rights (OWNER bypasses). Other link types ignore these.
    actingShopRole?: ShopRole;
    actingPermissions?: string[];
  }) {
    const toEmail = input.toEmail.toLowerCase().trim();
    const { linkType } = input;

    // TEAM invites add the recipient to the shop's staff rather than
    // linking an address-book contact, so they take a separate path.
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

  /// Owner invites a staffer onto the shop's team. Enforces the
  /// "block dual-use" rule: the email can't already be a marketplace
  /// shopper, and can't already be on a team (including this shop's).
  /// On accept (see `respond`) a ShopMember row is created with
  /// `teamRole`.
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
    // The exact grant to apply on accept — normalised so manage⇒view.
    const teamPermissions = normalizeRights(input.teamPermissions ?? []);

    // Delegation cap (AUTH-TR-H1): a non-OWNER staffer with team:manage
    // must not mint a colleague holding rights they themselves lack. The
    // invite path was the one grant path missing this guard — setPermissions/
    // createRole/updateRole all enforce it. OWNER bypasses (returns []).
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
      // One pending TEAM invite per (shop, email).
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
      // Already staffs a shop (this one or another) — one team per user.
      // (An owner of their own shop has a membership too, so this also
      // stops you inviting another shop's owner.) A plain shopper account
      // has no membership and CAN be invited: accepting converts it to a
      // staff account for this shop (see respond()'s TEAM branch).
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
        } else if (invite.linkType === 'TEAM') {
          if (!invite.teamRoleName) {
            throw new TeamInviteError('INVALID_TEAM_ROLE');
          }
          // Re-check dual-use at accept time — the account may have
          // joined another team since the invite was sent. Rolls back
          // (the status flip above included) if so.
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
              // The grant captured at invite time (already normalised).
              permissions: normalizeRights(invite.teamPermissions),
            },
          });
          // Grant merchant-side access (if they were a shopper) and bump
          // the token floor so shopId/shopRole/role land on next request.
          await tx.user.update({
            where: { id: opts.userId },
            data: { role: 'OWNER', tokensValidFrom: respondedAt },
          });
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

      // A TEAM accept changed the accepting user's role + token floor
      // inside the transaction; mirror that into the in-process caches
      // so their very next request reflects merchant access + the new
      // shopId/shopRole without waiting out the 60s TTL.
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
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async claimPendingForNewUser(_opts: { userId: number; email: string }) {
    // SECURITY (AUTH-INVITE-1): a brand-new account is NO LONGER auto-bound to
    // pending invitations by matching the raw `toEmail`. That email-only claim
    // let an attacker who knew (or guessed) an invited address register it and
    // have the victim's PARTY/VENDOR/TEAM invites silently bound to them —
    // then accept (via /invitations/:id/accept, which trusts toUserId) to gain
    // that party's invoice/ledger history or a staff seat — all with NO proof
    // of mailbox ownership.
    //
    // Invitations are now claimed only by presenting the per-invite token from
    // the invite link: see `claimByToken` (POST /invitations/claim) for
    // PARTY/VENDOR and the token-based POST /auth/accept-invite for TEAM.
    // Possession of the token is the proof of mailbox control. Invites bound at
    // SEND time (when the recipient already had an account) are unaffected.
    //
    // FRONTEND FOLLOW-UP: the merchant/customer apps must call
    // `POST /invitations/claim { token }` from the invite deep-link so a user
    // who registers after being invited can still claim it.
    return { claimed: 0 };
  }

  /// Bind a PENDING invitation to the authenticated caller by presenting the
  /// per-invite `token` from the invite link. Possession of the token proves
  /// the recipient actually received the invitation — the secure replacement
  /// for the old email-match auto-claim (AUTH-INVITE-1). After a successful
  /// claim the invite is in the caller's inbox and can be accepted/declined
  /// through `respond` (POST /invitations/:id/accept). Idempotent for a token
  /// already claimed by the same caller; refuses a token bound to anyone else.
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
      // Atomic bind: only claim if still unbound, so two concurrent claims
      // (or a race with a send-time bind) can't both win.
      const claimed = await prisma.invitation.updateMany({
        where: { id: invite.id, toUserId: null, status: 'PENDING' },
        data: { toUserId: opts.userId },
      });
      if (claimed.count === 0) return { error: 'This invitation belongs to someone else.' as const };
    }
    return { ok: true as const, invitationId: invite.id };
  }

  /// Scheduled sweep (see scheduler.ts) — nothing else in the codebase ever
  /// revisits a PENDING invite once its `expiresAt` passes; the lazy checks
  /// in `respond`/`claimByToken`/`acceptTeamInvite` only fire if a user
  /// actually attempts to act on the dead invite, so an invite nobody
  /// touches after expiry sat at PENDING forever. This closes that gap by
  /// periodically flipping stale rows and notifying the original sender.
  async expireStalePendingInvites(): Promise<{ expired: number }> {
    const stale = await prisma.invitation.findMany({
      where: { status: 'PENDING', expiresAt: { lt: new Date() } },
      select: { id: true },
    });
    if (stale.length === 0) return { expired: 0 };
    const ids = stale.map((s) => s.id);

    // Guarded on status: 'PENDING' so a row that raced to ACCEPTED/DECLINED/
    // CANCELLED between the read above and this write is left untouched.
    await prisma.invitation.updateMany({
      where: { id: { in: ids }, status: 'PENDING' },
      data: { status: 'EXPIRED' },
    });

    // Re-read exactly the rows THIS sweep actually flipped — excludes any
    // that won that race above — so we only ever notify a sender about an
    // invite that genuinely expired unanswered.
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

/// Notifies the original sender that an invite they sent expired without a
/// response. Shared by every place a PENDING→EXPIRED transition happens
/// (the scheduled sweep, and the lazy on-demand checks in respond/
/// claimByToken/acceptTeamInvite) so the copy and `kind` stay in sync.
/// Caller is responsible for the actual status flip — this only notifies.
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

/// Human-readable label for a ShopRole, used in notification copy.
/// Falls back to "team member" when the role is somehow missing.
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
