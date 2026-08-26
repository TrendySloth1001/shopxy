import { createHash, randomBytes } from 'crypto';
import { generateSecret, generateURI, verifySync } from 'otplib';
import QRCode from 'qrcode';
import prisma from '../../infra/db/prisma.js';

const ISSUER = 'ShopXY';
const RECOVERY_CODE_COUNT = 10;
const SKEW_TOLERANCE_S = 30;

function hashCode(code: string): string {
  return createHash('sha256').update(code.trim()).digest('hex');
}

function isValidTotp(code: string, secret: string): boolean {
  const token = code.trim();
  if (!/^\d{6}$/.test(token)) return false;
  return verifySync({ token, secret, epochTolerance: SKEW_TOLERANCE_S }).valid;
}

function makeRecoveryCode(): string {
  return randomBytes(4).toString('hex');
}

export const totpService = {
  async status(userId: number): Promise<{ enabled: boolean; pending: boolean }> {
    const u = await prisma.user.findUnique({
      where: { id: userId },
      select: { totpSecret: true, totpEnabledAt: true },
    });
    return {
      enabled: !!u?.totpEnabledAt,
      pending: !!u?.totpSecret && !u?.totpEnabledAt,
    };
  },

  async beginEnrollment(
    userId: number,
  ): Promise<{ error: string } | { otpauthUrl: string; qrDataUrl: string }> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, totpEnabledAt: true },
    });
    if (!user) return { error: 'User not found' };
    if (user.totpEnabledAt) return { error: 'Two-factor is already enabled' };

    const secret = generateSecret();
    await prisma.user.update({ where: { id: userId }, data: { totpSecret: secret } });

    const otpauthUrl = generateURI({ issuer: ISSUER, label: user.email, secret });
    const qrDataUrl = await QRCode.toDataURL(otpauthUrl);
    return { otpauthUrl, qrDataUrl };
  },

  async confirmEnrollment(
    userId: number,
    code: string,
  ): Promise<{ error: string } | { recoveryCodes: string[] }> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { totpSecret: true, totpEnabledAt: true },
    });
    if (!user?.totpSecret) return { error: 'Start two-factor setup first' };
    if (user.totpEnabledAt) return { error: 'Two-factor is already enabled' };
    if (!isValidTotp(code, user.totpSecret)) {
      return { error: 'That code is incorrect. Try again.' };
    }

    const recoveryCodes = Array.from({ length: RECOVERY_CODE_COUNT }, makeRecoveryCode);
    await prisma.user.update({
      where: { id: userId },
      data: {
        totpEnabledAt: new Date(),
        totpRecoveryCodes: recoveryCodes.map(hashCode),
      },
    });
    return { recoveryCodes };
  },

  async verifyForLogin(userId: number, code: string): Promise<boolean> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { totpSecret: true, totpEnabledAt: true, totpRecoveryCodes: true },
    });
    if (!user?.totpEnabledAt || !user.totpSecret) return false;

    if (isValidTotp(code, user.totpSecret)) {
      return true;
    }
    const hashed = hashCode(code);
    if (user.totpRecoveryCodes.includes(hashed)) {
      await prisma.user.update({
        where: { id: userId },
        data: { totpRecoveryCodes: user.totpRecoveryCodes.filter((c) => c !== hashed) },
      });
      return true;
    }
    return false;
  },

  async disable(userId: number, code: string): Promise<{ error: string } | { ok: true }> {
    const ok = await this.verifyForLogin(userId, code);
    if (!ok) return { error: 'That code is incorrect.' };
    await prisma.user.update({
      where: { id: userId },
      data: { totpSecret: null, totpEnabledAt: null, totpRecoveryCodes: [] },
    });
    return { ok: true };
  },
};
