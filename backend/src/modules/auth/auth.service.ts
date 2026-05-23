import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import prisma from '../../infra/db/prisma.js';
import { invitationsService } from '../invitations/invitations.service.js';
import { notificationsService } from '../notifications/notifications.service.js';
import { logger } from '../../shared/logging/logger.js';

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`${name} is required — refusing to start with a default secret`);
  return v;
}

const ACCESS_SECRET = requireEnv('JWT_ACCESS_SECRET');
const REFRESH_SECRET = requireEnv('JWT_REFRESH_SECRET');
const REFRESH_EXPIRES_MS = 7 * 24 * 60 * 60 * 1000;

const safeUserSelect = {
  id: true,
  email: true,
  name: true,
  role: true,
  isActive: true,
  emailNotifications: true,
  shopName: true,
  shopAddress: true,
  shopCity: true,
  shopState: true,
  shopStateCode: true,
  shopPinCode: true,
  shopGstin: true,
  shopPan: true,
  upiVpa: true,
  createdAt: true,
} as const;

function signAccess(userId: number, email: string, role: string): string {
  return jwt.sign({ sub: userId, email, role }, ACCESS_SECRET, { expiresIn: '15m' });
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

export class AuthService {
  async register(data: { email: string; name: string; password: string }) {
    const email = data.email.toLowerCase().trim();
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return { error: 'Email already registered' as const };

    const passwordHash = await bcrypt.hash(data.password, 12);
    // Self-signup defaults to CUSTOMER. OWNER accounts must be created
    // out-of-band (seed script or admin endpoint) — otherwise anyone hitting
    // /auth/register gets full merchant access (audit C1).
    const user = await prisma.user.create({
      data: { email, name: data.name.trim(), passwordHash, role: 'CUSTOMER' },
      select: safeUserSelect,
    });

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

    const accessToken = signAccess(user.id, user.email, user.role);
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

    const accessToken = signAccess(user.id, user.email, user.role);
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
      select: { id: true, email: true, role: true, isActive: true },
    });
    if (!user || !user.isActive) {
      await prisma.refreshToken.delete({ where: { id: stored.id } });
      return { error: 'Account not found or deactivated' as const };
    }

    // Rotate: delete old token, issue new pair
    await prisma.refreshToken.delete({ where: { id: stored.id } });
    const accessToken = signAccess(user.id, user.email, user.role);
    const refreshToken = await createRefreshToken(user.id);
    return { accessToken, refreshToken };
  }

  async logout(token: string) {
    await prisma.refreshToken.deleteMany({ where: { token } });
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
      shopPan?: string | null;
      upiVpa?: string | null;
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
      shopPan?: string | null;
      upiVpa?: string | null;
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
    if (data.shopPan !== undefined) updates.shopPan = data.shopPan;
    if (data.upiVpa !== undefined) updates.upiVpa = data.upiVpa;
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
    await prisma.user.update({ where: { id: userId }, data: { passwordHash } });
    // Revoke all sessions after password change
    await prisma.refreshToken.deleteMany({ where: { userId } });

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
}

export const authService = new AuthService();
