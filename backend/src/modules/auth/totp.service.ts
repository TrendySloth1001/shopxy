import { createHash, randomBytes } from 'crypto';
import { generateSecret, generateURI, verifySync } from 'otplib';
import QRCode from 'qrcode';
import prisma from '../../infra/db/prisma.js';

/**
 * TOTP two-factor auth (RFC 6238) for the login flow.
 *
 * Lifecycle: `beginEnrollment` mints a secret (stored, but 2FA stays OFF until
 * confirmed) → the user scans the QR in an authenticator app → `confirmEnrollment`
 * verifies a live code, flips 2FA on and returns one-time **recovery codes**.
 * `verifyForLogin` gates login for enabled accounts, accepting either a live
 * code or a recovery code (consumed on use). `disable` turns it back off.
 *
 * NOTE (productionisation): the shared secret is stored as-is. Before this is a
 * primary security control, encrypt it at rest (AES-256-GCM with a KMS/env key);
 * the load/store is centralised here so that's a localised change. Recovery
 * codes are already stored only as SHA-256 hashes.
 */

const ISSUER = 'ShopXY';
const RECOVERY_CODE_COUNT = 10;
// Allow ±30s (one time-step) of clock skew between server and authenticator.
const SKEW_TOLERANCE_S = 30;

function hashCode(code: string): string {
  return createHash('sha256').update(code.trim()).digest('hex');
}

/** True when `code` is a currently-valid TOTP for `secret`. */
function isValidTotp(code: string, secret: string): boolean {
  const token = code.trim();
  // otplib throws on a non-6-digit token; recovery codes (8 hex chars) flow
  // through here first, so short-circuit anything that isn't a TOTP shape.
  if (!/^\d{6}$/.test(token)) return false;
  return verifySync({ token, secret, epochTolerance: SKEW_TOLERANCE_S }).valid;
}

/** Human-friendly one-time code, e.g. `a1b2c3d4` (8 hex chars). */
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

  /** Mint (or re-mint) a pending secret and return the QR + otpauth URL. */
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

  /** Verify a code against the pending secret; on success enable 2FA + return recovery codes. */
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
    // Returned exactly once — the plaintext is never persisted.
    return { recoveryCodes };
  },

  /**
   * Login-time check for an enabled account. Accepts a live TOTP code or a
   * one-time recovery code (which is consumed). Returns whether login may
   * proceed. Assumes the caller already verified the password.
   */
  async verifyForLogin(userId: number, code: string): Promise<boolean> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { totpSecret: true, totpEnabledAt: true, totpRecoveryCodes: true },
    });
    if (!user?.totpEnabledAt || !user.totpSecret) return false;

    if (isValidTotp(code, user.totpSecret)) {
      return true;
    }
    // Fall back to a recovery code — single use, so remove it on match.
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

  /** Disable 2FA after re-verifying a current code. */
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
