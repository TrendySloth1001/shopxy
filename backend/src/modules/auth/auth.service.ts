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
  // Bake the merchant's shopId into the JWT so handlers don't pay a
  // per-request lookup on the @unique ownerUserId index. Customer
  // accounts (and OWNERs without a shop yet) keep `shopId` undefined.
  let shopId: number | undefined;
  if (role === 'OWNER') {
    const shop = await prisma.shop.findUnique({
      where: { ownerUserId: userId },
      select: { id: true },
    });
    shopId = shop?.id;
  }
  return jwt.sign(
    { sub: userId, email, role, isPlatformAdmin, shopId },
    ACCESS_SECRET,
    { expiresIn: '15m' },
  );
}

const MAX_ACTIVE_REFRESH_TOKENS_PER_USER = 5;

async function createRefreshToken(userId: number): Promise<string> {
  const jti = crypto.randomUUID();
  const token = jwt.sign({ sub: userId, jti }, REFRESH_SECRET, { expiresIn: '7d' });
  const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_MS);
  await prisma.refreshToken.create({ data: { token, userId, expiresAt } });

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

    let user;
    if (data.role === 'OWNER') {
      const shopName = (data.shopName ?? '').trim();
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
        await tx.shop.create({
          data: {
            ownerUserId: created.id,
            name: shopName,
            slug,
          },
        });
        return created;
      });
    } else {
      user = await prisma.user.create({
        data: {
          email,
          name,
          passwordHash,
          role: 'CUSTOMER',
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
      logger.error({ event: 'invitation_claim_failed', userId: user.id, err });
      logger.warn({ userId: user.id, err }, 'invitation claim failed');
    }

    const accessToken = await signAccess(user.id, user.email, user.role, user.isPlatformAdmin);
    const refreshToken = await createRefreshToken(user.id);
    return { user, accessToken, refreshToken };
  }

  async login(email: string, password: string) {
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
    const { passwordHash: _p, ...safeUser } = user;
    return { user: safeUser, accessToken, refreshToken };
  }

  async refresh(token: string) {
    let payload: { sub: number };
    try {
      payload = jwt.verify(token, REFRESH_SECRET) as unknown as { sub: number };
    } catch {
      return { error: 'Invalid refresh token' as const };
    }

    const stored = await prisma.refreshToken.findUnique({ where: { token } });
    if (!stored || stored.expiresAt < new Date()) {
      if (stored) await prisma.refreshToken.delete({ where: { id: stored.id } });
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

    // Rotate: delete old token, issue new pair
    await prisma.refreshToken.delete({ where: { id: stored.id } });
    const accessToken = await signAccess(user.id, user.email, user.role, user.isPlatformAdmin);
    const refreshToken = await createRefreshToken(user.id);
    return { accessToken, refreshToken };
  }

  async logout(token: string) {
    await prisma.refreshToken.deleteMany({ where: { token } });
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
      console.warn('Failed to write password-change notification', userId, err);
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
