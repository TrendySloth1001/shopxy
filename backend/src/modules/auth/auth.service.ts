import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import prisma from '../../infra/db/prisma.js';

const ACCESS_SECRET = process.env.JWT_ACCESS_SECRET ?? 'dev-access-secret-CHANGE-IN-PROD';
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET ?? 'dev-refresh-secret-CHANGE-IN-PROD';
const REFRESH_EXPIRES_MS = 7 * 24 * 60 * 60 * 1000;

const safeUserSelect = {
  id: true,
  email: true,
  name: true,
  role: true,
  isActive: true,
  createdAt: true,
} as const;

function signAccess(userId: number, email: string, role: string): string {
  return jwt.sign({ sub: userId, email, role }, ACCESS_SECRET, { expiresIn: '15m' });
}

async function createRefreshToken(userId: number): Promise<string> {
  const jti = crypto.randomUUID();
  const token = jwt.sign({ sub: userId, jti }, REFRESH_SECRET, { expiresIn: '7d' });
  const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_MS);
  await prisma.refreshToken.create({ data: { token, userId, expiresAt } });
  return token;
}

export class AuthService {
  async register(data: { email: string; name: string; password: string }) {
    const email = data.email.toLowerCase().trim();
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return { error: 'Email already registered' as const };

    const passwordHash = await bcrypt.hash(data.password, 12);
    const user = await prisma.user.create({
      data: { email, name: data.name.trim(), passwordHash },
      select: safeUserSelect,
    });

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

  async changePassword(userId: number, currentPassword: string, newPassword: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { error: 'User not found' as const };

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) return { error: 'Current password is incorrect' as const };

    const passwordHash = await bcrypt.hash(newPassword, 12);
    await prisma.user.update({ where: { id: userId }, data: { passwordHash } });
    // Revoke all sessions after password change
    await prisma.refreshToken.deleteMany({ where: { userId } });
    return { ok: true };
  }
}

export const authService = new AuthService();
