import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { Role } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { invitationsService } from '../invitations/invitations.service.js';
import { notificationsService } from '../notifications/notifications.service.js';
import { logger } from '../../shared/logging/logger.js';
import { requireEnv } from '../../shared/env.js';
import { bumpTokensValidFromCache } from '../../shared/http/requireAuth.js';
import { normalizeRights } from '../../shared/http/permissions.js';
import { seedDefaultRoles } from '../team/team.service.js';

const ACCESS_SECRET = requireEnv('JWT_ACCESS_SECRET');
const REFRESH_SECRET = requireEnv('JWT_REFRESH_SECRET');
const REFRESH_EXPIRES_MS = 7 * 24 * 60 * 60 * 1000;

const safeUserSelect = {
  id: true,
  email: true,
  name: true,
  role: true,
  isPlatformAdmin: true,
  isActive: true,
  emailNotifications: true,
  shopName: true,
  shopAddress: true,
  shopCity: true,
  shopState: true,
  shopStateCode: true,
  shopPinCode: true,
  shopGstin: true,
  registrationType: true,
  shopPan: true,
  upiVpa: true,
  avatarUrl: true,
  phoneNumber: true,
  notifyOrders: true,
  notifyDeals: true,
  notifyAccount: true,
  notifyMessages: true,
  pushEnabled: true,
  smsEnabled: true,
  acceptedAt: true,
  createdAt: true,
} as const;

async function signAccess(
  userId: number,
  email: string,
  role: Role,
  isPlatformAdmin: boolean,
): Promise<string> {
  // shopId/shopRole are NOT baked into the JWT: requireAuth always
  // re-resolves membership for OWNER accounts (so a role change takes
  // effect within the cache TTL without re-login), which means a baked
  // value would only ever be overwritten. Dropping the sign-time
  // ShopMember lookup removes a wasted query on every token mint
  // (B-AUTH-7).
  return jwt.sign(
    { sub: userId, email, role, isPlatformAdmin },
    ACCESS_SECRET,
    { expiresIn: '15m' },
  );
}

const MAX_ACTIVE_REFRESH_TOKENS_PER_USER = 5;

/// SHA-256 hex of a refresh token. We persist only this digest, never
/// the raw JWT, so a read-only DB leak can't be replayed as a live
/// session (B-AUTH-1). Lookups hash the presented token and match it.
function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

/// Issues a refresh token and stores its hash. `family` ties the token
/// to a rotation lineage: a fresh login starts a new family; a rotation
/// keeps the parent's family so reuse of an already-rotated token can be
/// traced back and the whole family revoked (B-AUTH-2).
async function createRefreshToken(userId: number, family?: string): Promise<string> {
  const jti = crypto.randomUUID();
  const fam = family ?? crypto.randomUUID();
  const token = jwt.sign({ sub: userId, jti, family: fam }, REFRESH_SECRET, {
    expiresIn: '7d',
  });
  const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_MS);
  await prisma.refreshToken.create({
    data: { token: hashToken(token), family: fam, userId, expiresAt },
  });

  // Cap the number of active sessions per user. If we're now over the limit,
  // drop the oldest tokens (FIFO by createdAt). Keeps a forgotten device or
  // a stolen-cookie attacker from accumulating indefinite footholds.
  const active = await prisma.refreshToken.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
    select: { id: true },
  });
  if (active.length > MAX_ACTIVE_REFRESH_TOKENS_PER_USER) {
    const excess = active.slice(0, active.length - MAX_ACTIVE_REFRESH_TOKENS_PER_USER);
    await prisma.refreshToken.deleteMany({
      where: { id: { in: excess.map((t) => t.id) } },
    });
  }

  return token;
}

/// Lower-cases, collapses non-alphanumerics to single dashes, trims
/// leading/trailing dashes. Mirrors shop.service.ts's slugify — kept
/// inline here so auth doesn't cross-depend on the shop module.
function slugifyShop(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/// Returns `base`, `base-2`, `base-3`, … until a slug is free. Same
/// algorithm as shop.service.ts's `uniqueSlug`; duplicated rather than
/// imported to keep the auth module standalone.
async function uniqueShopSlug(base: string): Promise<string> {
  let candidate = base || 'shop';
  let suffix = 1;
  for (;;) {
    const existing = await prisma.shop.findUnique({
      where: { slug: candidate },
      select: { id: true },
    });
    if (!existing) return candidate;
    suffix += 1;
    candidate = `${base}-${suffix}`;
  }
}

/// Thrown inside acceptTeamInvite's transaction when the single-use
/// status claim loses a race (double submit) — rolls the new account +
/// membership back so one invite can't mint two staffers.
class InviteAlreadyUsedError extends Error {
  constructor() {
    super('INVITE_ALREADY_USED');
    this.name = 'InviteAlreadyUsedError';
  }
}

export class AuthService {
  async register(data: {
    email: string;
    name: string;
    password: string;
    role: Role;
    shopName?: string;
  }) {
    const email = data.email.toLowerCase().trim();
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return { error: 'Email already registered' as const };

    const passwordHash = await bcrypt.hash(data.password, 12);
    // App-origin signup: merchant app sends role=OWNER + a shopName so
    // we can create the User and their Shop in one transaction; the
    // customer app sends role=CUSTOMER. The legacy "OWNER must be
    // created out-of-band" stance (audit C1) is intentionally relaxed
    // here — the merchant app is the primary OWNER signup surface, and
    // ownership only gains anything when paired with a Shop, which we
    // create atomically below.
    const name = data.name.trim();
    const acceptedAt = new Date();

    // A pending TEAM invite for this email takes precedence over creating a
    // shop. The person was invited to join an existing shop's team, so even
    // when the merchant app sends role=OWNER + a shopName we must NOT mint
    // them their own shop: ShopMember.userId is unique, so owning a shop
    // would permanently block them from ever accepting the invite
    // (respond() throws ALREADY_ON_TEAM once any membership exists). Instead
    // we onboard them as staff of the inviting shop, atomically — the same
    // outcome as the token-based accept-invite screen, for people who just
    // hit "register" without the invite link. Customer-app (role=CUSTOMER)
    // signups keep the invite PENDING for explicit in-app acceptance.
    let user;
    const teamInvite =
      data.role === 'OWNER'
        ? await prisma.invitation.findFirst({
            where: {
              toEmail: email,
              toUserId: null,
              linkType: 'TEAM',
              status: 'PENDING',
              expiresAt: { gt: new Date() },
            },
            orderBy: { createdAt: 'desc' },
            select: {
              id: true,
              shopId: true,
              teamRoleName: true,
              teamPermissions: true,
              fromUserId: true,
            },
          })
        : null;

    if (teamInvite?.teamRoleName) {
      const invite = teamInvite;
      const roleName = teamInvite.teamRoleName;
      try {
        user = await prisma.$transaction(async (tx) => {
          // Single-use claim first so a double submit can't onboard twice.
          const claim = await tx.invitation.updateMany({
            where: { id: invite.id, status: 'PENDING' },
            data: { status: 'ACCEPTED', respondedAt: new Date() },
          });
          if (claim.count === 0) throw new InviteAlreadyUsedError();
          // role=OWNER on the User row is "merchant app access", not shop
          // ownership — they get into the merchant app, but their team role
          // lives on ShopMember below (STAFF of the inviting shop). No Shop
          // is created.
          const created = await tx.user.create({
            data: { email, name, passwordHash, role: 'OWNER', acceptedAt },
            select: safeUserSelect,
          });
          await tx.invitation.update({
            where: { id: invite.id },
            data: { toUserId: created.id },
          });
          await tx.shopMember.create({
            data: {
              shopId: invite.shopId,
              userId: created.id,
              role: 'STAFF',
              roleName,
              permissions: normalizeRights(invite.teamPermissions),
            },
          });
          await tx.notification.create({
            data: {
              userId: invite.fromUserId,
              kind: 'INVITE_ACCEPTED',
              title: `${email} joined your team`,
              body: `As ${roleName}`,
              data: { invitationId: invite.id, linkType: 'TEAM' },
            },
          });
          return created;
        });
      } catch (err) {
        // Lost the single-use race (the invite was consumed elsewhere) —
        // fall through to a plain account below rather than failing signup.
        if (!(err instanceof InviteAlreadyUsedError)) throw err;
      }
    }

    const shopName = (data.shopName ?? '').trim();
    if (!user && data.role === 'OWNER' && shopName) {
      const slug = await uniqueShopSlug(slugifyShop(shopName));
      user = await prisma.$transaction(async (tx) => {
        const created = await tx.user.create({
          data: {
            email,
            name,
            passwordHash,
            role: 'OWNER',
            // Mirror the shop name into the User so invoice headers /
            // GST footers have a value to render without a follow-up
            // Shop lookup. The merchant can later refine the legal name
            // separately from the public shop name in settings.
            shopName,
            acceptedAt,
          },
          select: safeUserSelect,
        });
        const shop = await tx.shop.create({
          data: {
            ownerUserId: created.id,
            name: shopName,
            slug,
          },
          select: { id: true },
        });
        // Seed the owner's team membership in the same transaction.
        // shopId/shopRole now resolve from ShopMember, so without this
        // row a brand-new owner couldn't reach their own shop.
        await tx.shopMember.create({
          data: { shopId: shop.id, userId: created.id, role: 'OWNER' },
        });
        // Seed the shop's starter roles (Manager/Stockist/Cashier) so the
        // Team & roles screen is populated from day one.
        await seedDefaultRoles(tx, shop.id);
        return created;
      });
    } else if (!user) {
      // No shop created at signup. A merchant (role=OWNER) who didn't send a
      // shopName is created shopless and names their shop on the onboarding
      // screen next (POST /me/onboarding/shop); a customer stays a customer.
      // Either way no Shop/ShopMember row is created here.
      user = await prisma.user.create({
        data: {
          email,
          name,
          passwordHash,
          role: data.role === 'OWNER' ? 'OWNER' : 'CUSTOMER',
          // DPDP §6: record the moment of consent. The controller enforces
          // that both terms + privacy were ticked before reaching the
          // service, so reaching here implies a freely-given consent.
          acceptedAt,
        },
        select: safeUserSelect,
      });
    }

    // Attach any pending invitations addressed to this email so the new
    // user sees them on first login. Best-effort — a failure here must
    // not block account creation.
    try {
      await invitationsService.claimPendingForNewUser({ userId: user.id, email });
    } catch (err) {
      // Stable `event` tag so alerts can match without parsing free-form text.
      // pino emits JSON natively so a single structured call covers both the
      // human-readable warn and the machine-readable error record we used to
      // emit as two separate console calls.
      logger.error({ event: 'invitation_claim_failed', userId: user.id, err }, 'invitation claim failed');
    }

    const accessToken = await signAccess(user.id, user.email, user.role, user.isPlatformAdmin);
    const refreshToken = await createRefreshToken(user.id);
    return { user, accessToken, refreshToken };
  }

  /// Read-only view of a TEAM invitation by its token, for the staff
  /// accept-invite screen ("<Shop> invited you to join as Manager").
  /// Returns a friendly error string for unusable tokens so the screen
  /// can explain why rather than 404.
  async previewTeamInvite(token: string) {
    const invite = await prisma.invitation.findUnique({
      where: { token },
      select: {
        toEmail: true,
        teamRoleName: true,
        linkType: true,
        status: true,
        expiresAt: true,
        fromShopName: true,
      },
    });
    if (!invite || invite.linkType !== 'TEAM') {
      return { error: 'This invitation link is not valid.' as const };
    }
    if (invite.status !== 'PENDING') {
      return { error: 'This invitation has already been used.' as const };
    }
    if (invite.expiresAt < new Date()) {
      return { error: 'This invitation has expired.' as const };
    }
    return {
      invite: {
        email: invite.toEmail,
        roleLabel: invite.teamRoleName ?? 'Staff',
        shopName: invite.fromShopName,
      },
    };
  }

  /// Brand-new staffer accepts a TEAM invite and sets up their account
  /// in one step: validates the token, creates a shopless merchant
  /// (role=OWNER) account, makes them a ShopMember with the invited
  /// role, and marks the invite accepted — atomically. No tokensValidFrom
  /// bump (there are no prior sessions to revoke), so the freshly-minted
  /// access token isn't immediately invalidated. Existing accounts use
  /// the in-app notification accept flow instead.
  async acceptTeamInvite(data: { token: string; name?: string; password: string }) {
    const invite = await prisma.invitation.findUnique({
      where: { token: data.token },
      select: {
        id: true,
        shopId: true,
        toEmail: true,
        teamRoleName: true,
        teamPermissions: true,
        linkType: true,
        status: true,
        expiresAt: true,
        fromUserId: true,
      },
    });
    if (!invite || invite.linkType !== 'TEAM' || !invite.teamRoleName) {
      return { error: 'This invitation link is not valid.' as const };
    }
    if (invite.status !== 'PENDING') {
      return { error: 'This invitation has already been used.' as const };
    }
    if (invite.expiresAt < new Date()) {
      return { error: 'This invitation has expired.' as const };
    }
    const email = invite.toEmail.toLowerCase().trim();
    const existing = await prisma.user.findUnique({ where: { email }, select: { id: true } });
    if (existing) {
      return {
        error:
          'An account with this email already exists. Sign in and accept from your notifications.' as const,
      };
    }

    const passwordHash = await bcrypt.hash(data.password, 12);
    const teamRoleName = invite.teamRoleName;
    // Default the name from the email local part when not supplied, so an
    // account that isn't fully set up still has a sensible label.
    const finalName = data.name?.trim() || email.split('@')[0];
    let user;
    try {
      user = await prisma.$transaction(async (tx) => {
        // Single-use claim: flip PENDING→ACCEPTED first so a double
        // submit can't create two accounts off one invite.
        const claim = await tx.invitation.updateMany({
          where: { id: invite.id, status: 'PENDING' },
          data: { status: 'ACCEPTED', respondedAt: new Date() },
        });
        if (claim.count === 0) throw new InviteAlreadyUsedError();

        const created = await tx.user.create({
          data: {
            email,
            name: finalName,
            passwordHash,
            role: 'OWNER',
            acceptedAt: new Date(),
          },
          select: safeUserSelect,
        });
        await tx.invitation.update({
          where: { id: invite.id },
          data: { toUserId: created.id },
        });
        await tx.shopMember.create({
          data: {
            shopId: invite.shopId,
            userId: created.id,
            role: 'STAFF',
            roleName: teamRoleName,
            permissions: normalizeRights(invite.teamPermissions),
          },
        });
        await tx.notification.create({
          data: {
            userId: invite.fromUserId,
            kind: 'INVITE_ACCEPTED',
            title: `${invite.toEmail} joined your team`,
            body: `As ${teamRoleName}`,
            data: { invitationId: invite.id, linkType: 'TEAM' },
          },
        });
        return created;
      });
    } catch (err) {
      if (err instanceof InviteAlreadyUsedError) {
        return { error: 'This invitation has already been used.' as const };
      }
      throw err;
    }

    const accessToken = await signAccess(user.id, user.email, user.role, user.isPlatformAdmin);
    const refreshToken = await createRefreshToken(user.id);
    return { user, accessToken, refreshToken };
  }

  async login(email: string, password: string) {
    // Read the full row (incl. passwordHash + isActive) for the credential
    // check, but only ever return the `safeUserSelect` projection so the
    // wire response matches register/getMe and can't leak internal columns
    // like tokensValidFrom (B-AUTH-5).
    const user = await prisma.user.findUnique({
      where: { email: email.toLowerCase().trim() },
    });
    // Constant-time compare even for missing users (prevent user enumeration)
    const dummyHash = '$2b$12$invalidhashpadding000000000000000000000000000000000000';
    const valid = user
      ? await bcrypt.compare(password, user.passwordHash)
      : await bcrypt.compare(password, dummyHash).then(() => false);

    if (!user || !user.isActive || !valid) {
      return { error: 'Invalid email or password' as const };
    }

    const accessToken = await signAccess(user.id, user.email, user.role, user.isPlatformAdmin);
    const refreshToken = await createRefreshToken(user.id);
    const safeUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: safeUserSelect,
    });
    return { user: safeUser, accessToken, refreshToken };
  }

  async refresh(token: string) {
    let payload: { sub: number; family?: string };
    try {
      payload = jwt.verify(token, REFRESH_SECRET) as unknown as {
        sub: number;
        family?: string;
      };
    } catch {
      return { error: 'Invalid refresh token' as const };
    }

    const tokenHash = hashToken(token);
    const stored = await prisma.refreshToken.findUnique({ where: { token: tokenHash } });
    if (!stored) {
      // The JWT verified (valid signature, unexpired) but its hash isn't
      // stored — it was already rotated away or logged out. If its family
      // still has live members, this is a replay of a rotated token, so
      // revoke the entire family and force a fresh login (B-AUTH-2).
      if (payload.family) {
        const familyAlive = await prisma.refreshToken.findFirst({
          where: { family: payload.family },
          select: { id: true },
        });
        if (familyAlive) {
          await prisma.refreshToken.deleteMany({ where: { family: payload.family } });
        }
      }
      return { error: 'Refresh token expired or revoked' as const };
    }
    if (stored.expiresAt < new Date()) {
      await prisma.refreshToken.delete({ where: { id: stored.id } });
      return { error: 'Refresh token expired or revoked' as const };
    }

    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, email: true, role: true, isPlatformAdmin: true, isActive: true },
    });
    if (!user || !user.isActive) {
      await prisma.refreshToken.delete({ where: { id: stored.id } });
      return { error: 'Account not found or deactivated' as const };
    }

    // Rotate within the same family: delete old token, issue new pair.
    await prisma.refreshToken.delete({ where: { id: stored.id } });
    const accessToken = await signAccess(user.id, user.email, user.role, user.isPlatformAdmin);
    const refreshToken = await createRefreshToken(user.id, stored.family);
    return { accessToken, refreshToken };
  }

  async logout(token: string) {
    await prisma.refreshToken.deleteMany({ where: { token: hashToken(token) } });
  }

  /// Revoke every refresh token for this user — drops other-device
  /// sessions in one shot — AND bumps `tokensValidFrom` so every
  /// outstanding access token also rejects at next requireAuth (closes
  /// the 15-minute TTL window that would otherwise let a stolen access
  /// token survive logout-all).
  async logoutAll(userId: number) {
    const stamp = new Date();
    await prisma.$transaction([
      prisma.refreshToken.deleteMany({ where: { userId } }),
      prisma.user.update({
        where: { id: userId },
        data: { tokensValidFrom: stamp },
      }),
    ]);
    bumpTokensValidFromCache(userId, stamp);
  }

  getMe(userId: number) {
    return prisma.user.findUnique({ where: { id: userId }, select: safeUserSelect });
  }

  async updateProfile(
    userId: number,
    data: {
      name?: string;
      emailNotifications?: boolean;
      // Shop profile fields — used to populate the invoice header /
      // GST footer / UPI QR. All independently optional so the settings
      // screen can PATCH a single field at a time.
      shopName?: string | null;
      shopAddress?: string | null;
      shopCity?: string | null;
      shopState?: string | null;
      shopStateCode?: string | null;
      shopPinCode?: string | null;
      shopGstin?: string | null;
      registrationType?: 'REGULAR' | 'COMPOSITION' | 'UNREGISTERED';
      shopPan?: string | null;
      upiVpa?: string | null;
      // Profile photo URL (upload-service path). Editable from both
      // the customer Edit Profile page and the merchant Settings page.
      avatarUrl?: string | null;
      // E.164-format phone, surfaced on customer Edit Profile.
      phoneNumber?: string | null;
      // Granular notification preferences (Phase 5).
      notifyOrders?: boolean;
      notifyDeals?: boolean;
      notifyAccount?: boolean;
      notifyMessages?: boolean;
      pushEnabled?: boolean;
      smsEnabled?: boolean;
    },
  ) {
    const updates: {
      name?: string;
      emailNotifications?: boolean;
      shopName?: string | null;
      shopAddress?: string | null;
      shopCity?: string | null;
      shopState?: string | null;
      shopStateCode?: string | null;
      shopPinCode?: string | null;
      shopGstin?: string | null;
      registrationType?: 'REGULAR' | 'COMPOSITION' | 'UNREGISTERED';
      shopPan?: string | null;
      upiVpa?: string | null;
      avatarUrl?: string | null;
      phoneNumber?: string | null;
      notifyOrders?: boolean;
      notifyDeals?: boolean;
      notifyAccount?: boolean;
      notifyMessages?: boolean;
      pushEnabled?: boolean;
      smsEnabled?: boolean;
    } = {};
    if (data.name !== undefined) updates.name = data.name;
    if (data.emailNotifications !== undefined) {
      updates.emailNotifications = data.emailNotifications;
    }
    if (data.shopName !== undefined) updates.shopName = data.shopName;
    if (data.shopAddress !== undefined) updates.shopAddress = data.shopAddress;
    if (data.shopCity !== undefined) updates.shopCity = data.shopCity;
    if (data.shopState !== undefined) updates.shopState = data.shopState;
    if (data.shopStateCode !== undefined) updates.shopStateCode = data.shopStateCode;
    if (data.shopPinCode !== undefined) updates.shopPinCode = data.shopPinCode;
    if (data.shopGstin !== undefined) updates.shopGstin = data.shopGstin;
    // Keep registration status coherent with the GSTIN. An explicit value
    // always wins (so a composition dealer can mark themselves COMPOSITION);
    // otherwise a GSTIN ⇒ REGULAR and a cleared GSTIN ⇒ UNREGISTERED.
    if (data.registrationType !== undefined) {
      updates.registrationType = data.registrationType;
    } else if (data.shopGstin !== undefined) {
      updates.registrationType = data.shopGstin ? 'REGULAR' : 'UNREGISTERED';
    }
    if (data.shopPan !== undefined) updates.shopPan = data.shopPan;
    if (data.upiVpa !== undefined) updates.upiVpa = data.upiVpa;
    if (data.avatarUrl !== undefined) updates.avatarUrl = data.avatarUrl;
    if (data.phoneNumber !== undefined) updates.phoneNumber = data.phoneNumber;
    if (data.notifyOrders !== undefined) updates.notifyOrders = data.notifyOrders;
    if (data.notifyDeals !== undefined) updates.notifyDeals = data.notifyDeals;
    if (data.notifyAccount !== undefined) updates.notifyAccount = data.notifyAccount;
    if (data.notifyMessages !== undefined) updates.notifyMessages = data.notifyMessages;
    if (data.pushEnabled !== undefined) updates.pushEnabled = data.pushEnabled;
    if (data.smsEnabled !== undefined) updates.smsEnabled = data.smsEnabled;
    if (Object.keys(updates).length === 0) {
      return prisma.user.findUnique({ where: { id: userId }, select: safeUserSelect });
    }
    return prisma.user.update({
      where: { id: userId },
      data: updates,
      select: safeUserSelect,
    });
  }

  async changePassword(userId: number, currentPassword: string, newPassword: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { error: 'User not found' as const };

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) return { error: 'Current password is incorrect' as const };

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const stamp = new Date();
    // Atomic: password rewrite + sessions revoked + tokensValidFrom
    // bumped so a stolen access token (issued before the change) is
    // rejected by requireAuth even within its 15-minute TTL.
    await prisma.$transaction([
      prisma.user.update({
        where: { id: userId },
        data: { passwordHash, tokensValidFrom: stamp },
      }),
      prisma.refreshToken.deleteMany({ where: { userId } }),
    ]);
    bumpTokensValidFromCache(userId, stamp);

    // Best-effort security alert. If the notification write fails we still
    // consider the password change successful — the user has already been
    // logged out everywhere via the refresh-token sweep above.
    try {
      await notificationsService.create({
        userId,
        kind: 'SECURITY',
        title: 'Password changed',
        body: "Your password was changed. If this wasn't you, contact support.",
      });
    } catch (err) {
      logger.warn({ event: 'password_change_notification_failed', userId, err }, 'Failed to write password-change notification');
    }

    return { ok: true };
  }

  /// DPDP §11 right-to-access: build a single JSON blob containing
  /// every row this user can reasonably claim as "their data". Shape
  /// depends on role — OWNERs get a full shop dump (so they can take
  /// their books elsewhere), CUSTOMERs get only their own activity.
  /// Refresh tokens are deliberately summarised to a count to avoid
  /// handing out live session secrets.
  async exportData(userId: number): Promise<Record<string, unknown>> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        notifications: true,
        invitationsSent: {
          include: {
            toUser: { select: { email: true, name: true } },
          },
        },
        invitationsReceived: {
          include: {
            fromUser: { select: { email: true, name: true } },
          },
        },
        linkedParties: { select: { id: true, name: true } },
        linkedVendors: { select: { id: true, name: true } },
        purchaseRequests: { include: { items: true } },
      },
    });
    if (!user) return { error: 'user_not_found' };

    const refreshTokenCount = await prisma.refreshToken.count({
      where: { userId },
    });

    // Strip the password hash before serialising — never include
    // credential material in an export, even one going to the owner.
    const { passwordHash: _ph, ...safeUser } = user;

    const blob: Record<string, unknown> = {
      exportedAt: new Date().toISOString(),
      user: safeUser,
      refreshTokenCount,
      notifications: user.notifications,
      invitationsSent: user.invitationsSent,
      invitationsReceived: user.invitationsReceived,
      linkedParties: user.linkedParties,
      linkedVendors: user.linkedVendors,
      purchaseRequests: user.purchaseRequests,
    };

    if (user.role === 'OWNER') {
      // Full shop dump — owners are the data fiduciary for THEIR shop's
      // rows. Every findMany MUST be scoped by shopId; without that
      // scoping, one merchant's export returns every other merchant's
      // data (DPDP/multi-tenant breach).
      const ownedShop = await prisma.shop.findUnique({
        where: { ownerUserId: userId },
        select: { id: true },
      });
      const shopId = ownedShop?.id;
      if (shopId !== undefined) {
        const [
          products,
          categories,
          parties,
          vendors,
          invoices,
          payments,
          challans,
          customFieldDefinitions,
          customFieldSections,
          stockTransactions,
          stockAdjustments,
        ] = await Promise.all([
          prisma.product.findMany({
            where: { shopId },
            include: { images: true, customFieldValues: true },
          }),
          // Categories are a global taxonomy shared across shops; not
          // scoped by shopId, so we return the full list as reference
          // data (not per-tenant content).
          prisma.category.findMany(),
          prisma.party.findMany({ where: { shopId } }),
          prisma.vendor.findMany({ where: { shopId } }),
          prisma.invoice.findMany({
            where: { shopId },
            include: { items: true },
          }),
          prisma.payment.findMany({ where: { shopId } }),
          prisma.challan.findMany({
            where: { shopId },
            include: { items: true },
          }),
          prisma.customFieldDefinition.findMany({ where: { shopId } }),
          prisma.customFieldSection.findMany({ where: { shopId } }),
          prisma.stockTransaction.findMany({ where: { shopId } }),
          prisma.stockAdjustment.findMany({
            where: { shopId },
            include: { items: true },
          }),
        ]);
        blob.shop = {
          shopId,
          products,
          categories,
          parties,
          vendors,
          invoices,
          payments,
          challans,
          customFieldDefinitions,
          customFieldSections,
          stockTransactions,
          stockAdjustments,
        };
      }
    }

    return blob;
  }

  /// DPDP §12 right-to-erasure. OWNER accounts that still hold legally
  /// retained records (CONFIRMED invoices within the 8-year Companies
  /// Act window) cannot be deleted — the user is told to contact
  /// support so we can do a controlled wipe. CUSTOMER accounts cascade
  /// freely because the schema's onDelete rules cover their footprint.
  async deleteAccount(userId: number, currentPassword: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { error: 'user_not_found' as const };

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) return { error: 'invalid_password' as const };

    if (user.role === 'OWNER') {
      // Companies Act §128 + GST §36: books of account must be kept
      // for 8 financial years. The check MUST be scoped to this user's
      // own shop — otherwise one merchant's retained invoices would
      // block every other merchant's account deletion.
      const ownedShop = await prisma.shop.findUnique({
        where: { ownerUserId: userId },
        select: { id: true },
      });
      if (ownedShop) {
        const cutoff = new Date();
        cutoff.setFullYear(cutoff.getFullYear() - 8);
        const protectedInvoices = await prisma.invoice.count({
          where: {
            shopId: ownedShop.id,
            status: 'CONFIRMED',
            invoiceDate: { gte: cutoff },
          },
        });
        if (protectedInvoices > 0) {
          return { error: 'cannot_delete_with_active_records' as const };
        }
      }
    }

    await prisma.$transaction(async (tx) => {
      // Cascade should handle refresh tokens but be explicit — keeps
      // the intent obvious and survives any future onDelete change.
      await tx.refreshToken.deleteMany({ where: { userId } });
      await tx.user.delete({ where: { id: userId } });
    });

    return { ok: true as const };
  }
}

export const authService = new AuthService();
