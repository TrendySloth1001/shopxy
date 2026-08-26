import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { Role } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { invitationsService, notifyInviteExpired } from '../invitations/invitations.service.js';
import { notificationsService } from '../notifications/notifications.service.js';
import { logger } from '../../shared/logging/logger.js';
import {
  JWT_ACCESS_SECRET as ACCESS_SECRET,
  JWT_REFRESH_SECRET as REFRESH_SECRET,
} from '../../shared/authSecrets.js';
import { bumpTokensValidFromCache } from '../../shared/http/requireAuth.js';
import { normalizeRights } from '../../shared/http/permissions.js';
import { seedDefaultRoles } from '../team/team.service.js';
import {
  loginLockRemainingMs,
  recordLoginFailure,
  clearLoginFailures,
} from './loginThrottle.js';
import { isPasswordBreached } from './passwordBreach.js';
import { revokeSession } from '../../shared/sessionRevocation.js';
import { totpService } from './totp.service.js';
import { verifyGoogleIdToken } from './googleAuth.js';
import { maskIp, type DeviceContext } from './deviceContext.js';
import { redisAvailable } from '../../infra/redis.js';
import { mailerEnabled } from '../../infra/mailer.js';
import {
  canVerifyEmail,
  generateOtp,
  sendOtpEmail,
  putPending,
  getPending,
  dropPending,
  verifyOtp,
  resendCooldownRemaining,
  markResent,
} from './emailVerification.js';
import {
  sendResetOtpEmail,
  putPendingReset,
  verifyResetOtp,
  dropPendingReset,
  resetCooldownRemaining,
  markResetSent,
} from './passwordReset.js';

const REFRESH_EXPIRES_MS = 7 * 24 * 60 * 60 * 1000;
const REMEMBER_EXPIRES_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_REMEMBER_TOKENS_PER_USER = 10;

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
  gstEffectiveFrom: true,
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
  googleId: true,
  recoveryPinSetAt: true,
  createdAt: true,
} as const;

async function signAccess(
  userId: number,
  email: string,
  role: Role,
  isPlatformAdmin: boolean,
  sid: string,
): Promise<string> {
  return jwt.sign(
    { sub: userId, email, role, isPlatformAdmin, sid },
    ACCESS_SECRET,
    { expiresIn: '15m' },
  );
}

async function issueSession(
  user: { id: number; email: string; role: Role; isPlatformAdmin: boolean },
  family?: string,
  device?: DeviceContext,
): Promise<{ accessToken: string; refreshToken: string }> {
  const sid = family ?? crypto.randomUUID();
  const accessToken = await signAccess(user.id, user.email, user.role, user.isPlatformAdmin, sid);
  const refreshToken = await createRefreshToken(user.id, sid, device);
  return { accessToken, refreshToken };
}

const MAX_ACTIVE_REFRESH_TOKENS_PER_USER = 5;

function unverifiedSignupAllowed(): boolean {
  return (
    process.env.ALLOW_UNVERIFIED_SIGNUP === 'true' &&
    process.env.NODE_ENV !== 'production'
  );
}

function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

async function createRefreshToken(
  userId: number,
  family?: string,
  device?: DeviceContext,
): Promise<string> {
  const jti = crypto.randomUUID();
  const fam = family ?? crypto.randomUUID();
  const token = jwt.sign({ sub: userId, jti, family: fam }, REFRESH_SECRET, {
    expiresIn: '7d',
  });
  const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_MS);
  await prisma.refreshToken.create({
    data: {
      token: hashToken(token),
      family: fam,
      userId,
      expiresAt,
      userAgent: device?.userAgent?.slice(0, 400) ?? null,
      deviceName: device?.deviceName?.slice(0, 120) ?? null,
      ipMasked: maskIp(device?.ip),
      lastUsedAt: new Date(),
    },
  });

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

function slugifyShop(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

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

class InviteAlreadyUsedError extends Error {
  constructor() {
    super('INVITE_ALREADY_USED');
    this.name = 'InviteAlreadyUsedError';
  }
}

export class AuthService {
  async register(
    data: {
      email: string;
      name: string;
      password: string;
      role: Role;
      shopName?: string;
    },
    device?: DeviceContext,
  ) {
    const email = data.email.toLowerCase().trim();
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return { error: 'Email already registered' as const };
    if (await isPasswordBreached(data.password)) {
      return { error: 'password_breached' as const };
    }

    const passwordHash = await bcrypt.hash(data.password, 12);
    const name = data.name.trim();
    const role: Role = data.role === 'OWNER' ? 'OWNER' : 'CUSTOMER';
    const shopName = (data.shopName ?? '').trim() || undefined;

    if (!canVerifyEmail()) {
      if (unverifiedSignupAllowed()) {
        logger.warn(
          { event: 'otp_bypassed_dev', email },
          'ALLOW_UNVERIFIED_SIGNUP is on — creating the account without email verification',
        );
        return this._finalizeRegistration({ email, name, passwordHash, role, shopName }, device);
      }
      logger.error(
        { event: 'otp_unavailable', redis: redisAvailable(), mailer: mailerEnabled() },
        'Signup blocked: email verification is unavailable',
      );
      return { error: 'verification_unavailable' as const };
    }

    const otp = generateOtp();
    if (!(await sendOtpEmail(email, name, otp))) {
      logger.error({ event: 'otp_send_failed', email }, 'Signup blocked: OTP email failed to send');
      return { error: 'verification_unavailable' as const };
    }
    await putPending({ name, email, passwordHash, role, shopName }, otp);
    return { pending: true as const, email };
  }

  async verifyEmailOtp(email: string, otp: string, device?: DeviceContext) {
    const norm = email.toLowerCase().trim();
    const res = await verifyOtp(norm, otp);
    if (!res.ok) return { error: res.reason };
    const existing = await prisma.user.findUnique({ where: { email: norm } });
    if (existing) {
      await dropPending(norm);
      return { error: 'Email already registered' as const };
    }
    const p = res.pending;
    const result = await this._finalizeRegistration(
      { email: p.email, name: p.name, passwordHash: p.passwordHash, role: p.role, shopName: p.shopName },
      device,
    );
    await dropPending(norm);
    return result;
  }

  async resendEmailOtp(email: string) {
    const norm = email.toLowerCase().trim();
    const pending = await getPending(norm);
    if (!pending) return { error: 'expired' as const };
    const cd = await resendCooldownRemaining(norm);
    if (cd > 0) return { error: 'cooldown' as const, retryAfterS: cd };
    const otp = generateOtp();
    if (!(await sendOtpEmail(norm, pending.name, otp))) {
      return { error: 'send_failed' as const };
    }
    await putPending(
      {
        name: pending.name,
        email: pending.email,
        passwordHash: pending.passwordHash,
        role: pending.role,
        shopName: pending.shopName,
      },
      otp,
    );
    await markResent(norm);
    return { ok: true as const };
  }

  private async _finalizeRegistration(
    data: { email: string; name: string; passwordHash: string; role: Role; shopName?: string },
    device?: DeviceContext,
  ) {
    const { email, name, passwordHash } = data;
    const acceptedAt = new Date();

    let user;
    const hasPendingTeamInvite =
      data.role === 'OWNER'
        ? (await prisma.invitation.count({
            where: {
              toEmail: email,
              toUserId: null,
              linkType: 'TEAM',
              status: 'PENDING',
              expiresAt: { gt: new Date() },
            },
          })) > 0
        : false;

    const shopName = (data.shopName ?? '').trim();
    if (!user && data.role === 'OWNER' && shopName && !hasPendingTeamInvite) {
      const slug = await uniqueShopSlug(slugifyShop(shopName));
      user = await prisma.$transaction(async (tx) => {
        const created = await tx.user.create({
          data: {
            email,
            name,
            passwordHash,
            role: 'OWNER',
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
        await tx.shopMember.create({
          data: { shopId: shop.id, userId: created.id, role: 'OWNER' },
        });
        await seedDefaultRoles(tx, shop.id);
        return created;
      });
    } else if (!user) {
      user = await prisma.user.create({
        data: {
          email,
          name,
          passwordHash,
          role: data.role === 'OWNER' ? 'OWNER' : 'CUSTOMER',
          acceptedAt,
        },
        select: safeUserSelect,
      });
    }

    try {
      await invitationsService.claimPendingForNewUser({ userId: user.id, email });
    } catch (err) {
      logger.error({ event: 'invitation_claim_failed', userId: user.id, err }, 'invitation claim failed');
    }

    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    return { user, accessToken, refreshToken };
  }

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

  async acceptTeamInvite(
    data: { token: string; name?: string; password: string },
    device?: DeviceContext,
  ) {
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
        displayName: true,
      },
    });
    if (!invite || invite.linkType !== 'TEAM' || !invite.teamRoleName) {
      return { error: 'This invitation link is not valid.' as const };
    }
    if (invite.status !== 'PENDING') {
      return { error: 'This invitation has already been used.' as const };
    }
    if (invite.expiresAt < new Date()) {
      const flipped = await prisma.invitation.updateMany({
        where: { id: invite.id, status: 'PENDING' },
        data: { status: 'EXPIRED' },
      });
      if (flipped.count > 0) await notifyInviteExpired(prisma, invite);
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
    if (await isPasswordBreached(data.password)) {
      return { error: 'password_breached' as const };
    }

    const passwordHash = await bcrypt.hash(data.password, 12);
    const teamRoleName = invite.teamRoleName;
    const finalName = data.name?.trim() || email.split('@')[0];
    let user;
    try {
      user = await prisma.$transaction(async (tx) => {
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

    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    return { user, accessToken, refreshToken };
  }

  async login(email: string, password: string, totpCode?: string, device?: DeviceContext) {
    const normEmail = email.toLowerCase().trim();

    const lockedMs = await loginLockRemainingMs(normEmail);
    if (lockedMs > 0) {
      return { error: 'locked' as const, retryAfterMs: lockedMs };
    }

    const user = await prisma.user.findUnique({
      where: { email: normEmail },
    });
    const dummyHash = '$2b$12$invalidhashpadding000000000000000000000000000000000000';
    const valid = user
      ? await bcrypt.compare(password, user.passwordHash)
      : await bcrypt.compare(password, dummyHash).then(() => false);

    if (!user || !user.isActive || !valid) {
      await recordLoginFailure(normEmail);
      return { error: 'Invalid email or password' as const };
    }

    if (user.totpEnabledAt) {
      if (!totpCode) {
        return { error: '2fa_required' as const };
      }
      const okTotp = await totpService.verifyForLogin(user.id, totpCode);
      if (!okTotp) {
        await recordLoginFailure(normEmail);
        return { error: '2fa_invalid' as const };
      }
    }

    await clearLoginFailures(normEmail);

    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    const safeUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: safeUserSelect,
    });
    return { user: safeUser, accessToken, refreshToken };
  }

  async googleAuth(idToken: string, device?: DeviceContext) {
    const profile = await verifyGoogleIdToken(idToken);
    if (!profile) return { error: 'invalid_google_token' as const };

    let user = await prisma.user.findUnique({ where: { googleId: profile.googleId } });

    if (!user) {
      const existing = await prisma.user.findUnique({ where: { email: profile.email } });
      if (existing) {
        user = await prisma.user.update({
          where: { id: existing.id },
          data: { googleId: profile.googleId },
        });
      } else {
        const passwordHash = await bcrypt.hash(crypto.randomUUID(), 12);
        const created = await this._finalizeRegistration(
          { email: profile.email, name: profile.name, passwordHash, role: 'OWNER' },
          device,
        );
        await prisma.user.update({
          where: { id: created.user!.id },
          data: { googleId: profile.googleId },
        });
        return {
          user: created.user,
          accessToken: created.accessToken,
          refreshToken: created.refreshToken,
          needsPinSetup: true as const,
        };
      }
    }

    if (!user.isActive) return { error: 'account_disabled' as const };

    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    const safeUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: safeUserSelect,
    });
    return {
      user: safeUser,
      accessToken,
      refreshToken,
      needsPinSetup: !user.recoveryPinHash,
    };
  }

  async setRecoveryPin(userId: number, pin: string) {
    const recoveryPinHash = await bcrypt.hash(pin, 12);
    await prisma.user.update({
      where: { id: userId },
      data: { recoveryPinHash, recoveryPinSetAt: new Date() },
    });
    return { ok: true as const };
  }

  async loginWithRecoveryPin(email: string, pin: string, totpCode?: string, device?: DeviceContext) {
    const normEmail = email.toLowerCase().trim();

    const lockedMs = await loginLockRemainingMs(normEmail);
    if (lockedMs > 0) return { error: 'locked' as const, retryAfterMs: lockedMs };

    const user = await prisma.user.findUnique({ where: { email: normEmail } });
    const dummyHash = '$2b$12$invalidhashpadding000000000000000000000000000000000000';
    const valid = user?.recoveryPinHash
      ? await bcrypt.compare(pin, user.recoveryPinHash)
      : await bcrypt.compare(pin, dummyHash).then(() => false);

    if (!user || !user.isActive || !valid) {
      await recordLoginFailure(normEmail);
      return { error: 'Invalid email or recovery PIN' as const };
    }

    if (user.totpEnabledAt) {
      if (!totpCode) return { error: '2fa_required' as const };
      const okTotp = await totpService.verifyForLogin(user.id, totpCode);
      if (!okTotp) {
        await recordLoginFailure(normEmail);
        return { error: '2fa_invalid' as const };
      }
    }

    await clearLoginFailures(normEmail);
    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    const safeUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: safeUserSelect,
    });
    return { user: safeUser, accessToken, refreshToken };
  }

  async refresh(token: string, device?: DeviceContext) {
    let payload: { sub: number; family?: string };
    try {
      payload = jwt.verify(token, REFRESH_SECRET, { algorithms: ['HS256'] }) as unknown as {
        sub: number;
        family?: string;
      };
    } catch {
      return { error: 'Invalid refresh token' as const };
    }

    const tokenHash = hashToken(token);
    const stored = await prisma.refreshToken.findUnique({ where: { token: tokenHash } });
    if (!stored) {
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

    await prisma.refreshToken.delete({ where: { id: stored.id } });
    const { accessToken, refreshToken } = await issueSession(user, stored.family, device);
    return { accessToken, refreshToken };
  }

  async logout(token: string) {
    const stored = await prisma.refreshToken.findUnique({
      where: { token: hashToken(token) },
      select: { id: true, family: true },
    });
    if (!stored) return;
    await prisma.refreshToken.delete({ where: { id: stored.id } });
    await revokeSession(stored.family);
  }

  async logoutAll(userId: number) {
    const stamp = new Date();
    await prisma.$transaction([
      prisma.refreshToken.deleteMany({ where: { userId } }),
      prisma.rememberToken.deleteMany({ where: { userId } }),
      prisma.user.update({
        where: { id: userId },
        data: { tokensValidFrom: stamp },
      }),
    ]);
    bumpTokensValidFromCache(userId, stamp);
  }

  async issueRememberToken(userId: number, label?: string | null) {
    const raw = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + REMEMBER_EXPIRES_MS);
    await prisma.rememberToken.create({
      data: { userId, tokenHash: hashToken(raw), label: label?.slice(0, 80) ?? null, expiresAt },
    });
    const active = await prisma.rememberToken.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (active.length > MAX_REMEMBER_TOKENS_PER_USER) {
      const excess = active.slice(0, active.length - MAX_REMEMBER_TOKENS_PER_USER);
      await prisma.rememberToken.deleteMany({ where: { id: { in: excess.map((t) => t.id) } } });
    }
    return { rememberToken: raw, expiresAt };
  }

  async rememberLogin(raw: string, device?: DeviceContext) {
    const stored = await prisma.rememberToken.findUnique({
      where: { tokenHash: hashToken(raw) },
      select: { id: true, userId: true, label: true, expiresAt: true },
    });
    if (!stored) return { error: 'This saved sign-in is no longer valid' as const };
    if (stored.expiresAt < new Date()) {
      await prisma.rememberToken.delete({ where: { id: stored.id } });
      return { error: 'This saved sign-in has expired' as const };
    }
    const user = await prisma.user.findUnique({
      where: { id: stored.userId },
      select: { ...safeUserSelect, isActive: true },
    });
    if (!user || !user.isActive) {
      await prisma.rememberToken.delete({ where: { id: stored.id } });
      return { error: 'This account is no longer available' as const };
    }

    const newRaw = crypto.randomBytes(32).toString('hex');
    const rememberExpiresAt = new Date(Date.now() + REMEMBER_EXPIRES_MS);
    await prisma.$transaction([
      prisma.rememberToken.delete({ where: { id: stored.id } }),
      prisma.rememberToken.create({
        data: { userId: user.id, tokenHash: hashToken(newRaw), label: stored.label, expiresAt: rememberExpiresAt },
      }),
    ]);
    const { isActive: _isActive, ...safeUser } = user;
    const { accessToken, refreshToken } = await issueSession(safeUser, undefined, device);
    return { user: safeUser, accessToken, refreshToken, rememberToken: newRaw, rememberExpiresAt };
  }

  async forgetRememberToken(raw: string) {
    await prisma.rememberToken.deleteMany({ where: { tokenHash: hashToken(raw) } });
  }

  getMe(userId: number) {
    return prisma.user.findUnique({ where: { id: userId }, select: safeUserSelect });
  }

  async updateProfile(
    userId: number,
    data: {
      name?: string;
      emailNotifications?: boolean;
      shopName?: string | null;
      shopAddress?: string | null;
      shopCity?: string | null;
      shopState?: string | null;
      shopStateCode?: string | null;
      shopPinCode?: string | null;
      shopGstin?: string | null;
      gstEffectiveFrom?: string | null;
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
      gstEffectiveFrom?: Date | null;
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
    if (data.registrationType !== undefined) {
      updates.registrationType = data.registrationType;
    } else if (data.shopGstin !== undefined) {
      updates.registrationType = data.shopGstin ? 'REGULAR' : 'UNREGISTERED';
    }
    if (data.gstEffectiveFrom !== undefined) {
      updates.gstEffectiveFrom = data.gstEffectiveFrom
        ? new Date(`${data.gstEffectiveFrom}T00:00:00.000Z`)
        : null;
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

    if (data.shopGstin !== undefined) {
      const current = await prisma.user.findUnique({
        where: { id: userId },
        select: { shopGstin: true, gstEffectiveFrom: true },
      });
      if (!current) return null;
      const isNewGstinRegistration =
        data.shopGstin !== null && data.shopGstin !== current.shopGstin;
      if (isNewGstinRegistration && updates.registrationType === 'REGULAR') {
        const resolvedEffectiveFrom =
          data.gstEffectiveFrom !== undefined
            ? updates.gstEffectiveFrom
            : current.gstEffectiveFrom;
        if (resolvedEffectiveFrom == null) {
          return { error: 'GST_EFFECTIVE_DATE_REQUIRED' as const };
        }
      }
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
    if (await isPasswordBreached(newPassword)) {
      return { error: 'password_breached' as const };
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const stamp = new Date();
    await prisma.$transaction([
      prisma.user.update({
        where: { id: userId },
        data: { passwordHash, tokensValidFrom: stamp },
      }),
      prisma.refreshToken.deleteMany({ where: { userId } }),
      prisma.rememberToken.deleteMany({ where: { userId } }),
    ]);
    bumpTokensValidFromCache(userId, stamp);

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

  async requestPasswordReset(email: string) {
    const norm = email.toLowerCase().trim();

    if (!canVerifyEmail()) {
      logger.error(
        { event: 'pwreset_unavailable', redis: redisAvailable(), mailer: mailerEnabled() },
        'Password reset requested but the OTP infra is unavailable',
      );
      return { ok: true as const };
    }

    const user = await prisma.user.findUnique({
      where: { email: norm },
      select: { id: true, name: true, isActive: true },
    });
    if (!user || !user.isActive) {
      logger.info({ event: 'pwreset_unknown_email' }, 'Password reset for an unknown/inactive address');
      return { ok: true as const };
    }

    if ((await resetCooldownRemaining(norm)) > 0) {
      logger.info({ event: 'pwreset_cooldown', userId: user.id }, 'Password reset suppressed by cooldown');
      return { ok: true as const };
    }

    const otp = generateOtp();
    if (!(await sendResetOtpEmail(norm, user.name, otp))) {
      logger.error({ event: 'pwreset_send_failed', userId: user.id }, 'Password reset email failed to send');
      return { ok: true as const };
    }
    await putPendingReset(norm, otp);
    await markResetSent(norm);
    return { ok: true as const };
  }

  async resetPassword(email: string, otp: string, newPassword: string) {
    const norm = email.toLowerCase().trim();

    const check = await verifyResetOtp(norm, otp);
    if (!check.ok) return { error: check.reason };

    const user = await prisma.user.findUnique({
      where: { email: norm },
      select: { id: true, isActive: true },
    });
    if (!user || !user.isActive) {
      await dropPendingReset(norm);
      return { error: 'expired' as const };
    }

    if (await isPasswordBreached(newPassword)) {
      return { error: 'password_breached' as const };
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const stamp = new Date();
    await prisma.$transaction([
      prisma.user.update({
        where: { id: user.id },
        data: { passwordHash, tokensValidFrom: stamp },
      }),
      prisma.refreshToken.deleteMany({ where: { userId: user.id } }),
      prisma.rememberToken.deleteMany({ where: { userId: user.id } }),
    ]);
    bumpTokensValidFromCache(user.id, stamp);
    await dropPendingReset(norm);

    try {
      await notificationsService.create({
        userId: user.id,
        kind: 'SECURITY',
        title: 'Password reset',
        body: "Your password was reset and every device was signed out. If this wasn't you, contact support immediately.",
      });
    } catch (err) {
      logger.warn(
        { event: 'pwreset_notification_failed', userId: user.id, err },
        'Failed to write password-reset notification',
      );
    }

    return { ok: true as const };
  }

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
        addresses: true,
        productReviews: true,
        wishlistItems: { include: { product: { select: { id: true, name: true } } } },
        cartItems: { include: { product: { select: { id: true, name: true } } } },
        customerOrders: { include: { shopOrders: { include: { items: true } } } },
        returnsRequested: { include: { items: true } },
      },
    });
    if (!user) return { error: 'user_not_found' };

    const refreshTokenCount = await prisma.refreshToken.count({
      where: { userId },
    });

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
      addresses: user.addresses,
      productReviews: user.productReviews,
      wishlistItems: user.wishlistItems,
      cartItems: user.cartItems,
      customerOrders: user.customerOrders,
      returnRequests: user.returnsRequested,
    };

    if (user.role === 'OWNER') {
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

  async deleteAccount(userId: number, currentPassword: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { error: 'user_not_found' as const };

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) return { error: 'invalid_password' as const };

    if (user.role === 'OWNER') {
      const ownedShop = await prisma.shop.findUnique({
        where: { ownerUserId: userId },
        select: { id: true },
      });
      if (ownedShop) {
        const [productCount, invoiceCount] = await Promise.all([
          prisma.product.count({ where: { shopId: ownedShop.id } }),
          prisma.invoice.count({ where: { shopId: ownedShop.id } }),
        ]);
        if (productCount > 0 || invoiceCount > 0) {
          return this.pseudonymiseAccount(userId);
        }
      }
    }

    await prisma.$transaction(async (tx) => {
      const reviewedProducts = await tx.productReview.findMany({
        where: { userId },
        select: { productId: true },
        distinct: ['productId'],
      });
      const affectedProductIds = reviewedProducts.map((r) => r.productId);
      if (affectedProductIds.length > 0) {
        await tx.productReview.deleteMany({ where: { userId } });
        for (const productId of affectedProductIds) {
          const agg = await tx.productReview.aggregate({
            where: { productId },
            _avg: { rating: true },
            _count: { _all: true },
          });
          await tx.product.update({
            where: { id: productId },
            data: {
              ratingAvg: agg._avg.rating,
              ratingCount: agg._count._all,
            },
          });
        }
      }

      await tx.refreshToken.deleteMany({ where: { userId } });
      await tx.user.delete({ where: { id: userId } });
    });

    return { ok: true as const, mode: 'deleted' as const };
  }

  private async pseudonymiseAccount(userId: number) {
    await prisma.$transaction(async (tx) => {
      const reviewedProducts = await tx.productReview.findMany({
        where: { userId },
        select: { productId: true },
        distinct: ['productId'],
      });
      const affectedProductIds = reviewedProducts.map((r) => r.productId);
      if (affectedProductIds.length > 0) {
        await tx.productReview.deleteMany({ where: { userId } });
        for (const productId of affectedProductIds) {
          const agg = await tx.productReview.aggregate({
            where: { productId },
            _avg: { rating: true },
            _count: { _all: true },
          });
          await tx.product.update({
            where: { id: productId },
            data: {
              ratingAvg: agg._avg.rating,
              ratingCount: agg._count._all,
            },
          });
        }
      }

      await tx.notification.deleteMany({ where: { userId } });
      await tx.userAddress.deleteMany({ where: { userId } });
      await tx.wishlistItem.deleteMany({ where: { userId } });
      await tx.cartItem.deleteMany({ where: { userId } });
      await tx.refreshToken.deleteMany({ where: { userId } });
      await tx.rememberToken.deleteMany({ where: { userId } });

      await tx.user.update({
        where: { id: userId },
        data: {
          name: 'Deleted user',
          email: `deleted+${userId}@deleted.shopxy.invalid`,
          passwordHash: await bcrypt.hash(crypto.randomUUID(), 12),
          phoneNumber: null,
          avatarUrl: null,
          isActive: false,
          tokensValidFrom: new Date(),
          emailNotifications: false,
          notifyOrders: false,
          notifyDeals: false,
          notifyAccount: false,
          notifyMessages: false,
          pushEnabled: false,
          smsEnabled: false,
        },
      });
    });

    return { ok: true as const, mode: 'pseudonymised' as const };
  }
}

export const authService = new AuthService();
