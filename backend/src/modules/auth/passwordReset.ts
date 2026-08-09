import { createHash } from 'crypto';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';
import { sendMail } from '../../infra/mailer.js';

/**
 * Email-OTP for **forgotten passwords**. Proof of mailbox control is what
 * authorises the reset, the same root of trust signup uses.
 *
 * Deliberately a separate Redis namespace from the pending-registration codes
 * in {@link ./emailVerification}: a signup code must not be redeemable as a
 * password reset, nor the reverse. Two flows that both hold "a 6-digit code
 * for this email" in one keyspace is exactly how that confusion happens.
 *
 * Unlike signup, nothing about the account is held here — the account already
 * exists. Only the code hash and the attempt count live in Redis, so a Redis
 * dump can't be replayed into a password (the code is stored hashed, and it
 * is useless without also reaching the endpoint before it expires).
 */

interface PendingReset {
  otpHash: string;
  attempts: number;
}

const TTL_S = 15 * 60; // code validity
const MAX_ATTEMPTS = 5; // wrong-code tries before the code is burned
const RESEND_COOLDOWN_S = 30;

const key = (email: string) => `pwreset:${createHash('sha256').update(email).digest('hex')}`;
const cooldownKey = (email: string) =>
  `pwreset:cd:${createHash('sha256').update(email).digest('hex')}`;

function hashOtp(otp: string): string {
  return createHash('sha256').update(otp).digest('hex');
}

/** Send the reset code. Returns false if it couldn't be delivered. */
export async function sendResetOtpEmail(
  email: string,
  name: string,
  otp: string,
): Promise<boolean> {
  return sendMail({
    // Same category as signup: this is mail the user cannot proceed without,
    // so it sends regardless of MAIL_NOTIFICATIONS_ENABLED.
    category: 'otp',
    to: email,
    subject: `${otp} is your ShopXY password reset code`,
    text:
      `Hi ${name || 'there'},\n\n` +
      `Your ShopXY password reset code is ${otp}. It expires in 15 minutes.\n\n` +
      `If you didn't ask to reset your password, you can ignore this email — ` +
      `your password has not changed.`,
    html:
      `<p>Hi ${name || 'there'},</p>` +
      `<p>Your ShopXY password reset code is:</p>` +
      `<p style="font-size:28px;font-weight:700;letter-spacing:4px">${otp}</p>` +
      `<p>It expires in 15 minutes. If you didn't ask to reset your password, ` +
      `ignore this email — your password has not changed.</p>`,
  });
}

/** Store (or replace) the pending reset, hashing the code. */
export async function putPendingReset(email: string, otp: string): Promise<void> {
  const record: PendingReset = { otpHash: hashOtp(otp), attempts: 0 };
  await getRedis().set(key(email), JSON.stringify(record), 'EX', TTL_S);
}

export async function dropPendingReset(email: string): Promise<void> {
  if (!redisAvailable()) return;
  await getRedis().del(key(email));
}

/**
 * Check a submitted code. Success does NOT drop the record — the caller does
 * that only once the password is actually rewritten, so a failure between the
 * two doesn't strand the user with a burned code and no new password.
 */
export async function verifyResetOtp(
  email: string,
  otp: string,
): Promise<{ ok: true } | { ok: false; reason: 'expired' | 'invalid' | 'too_many' }> {
  if (!redisAvailable()) return { ok: false, reason: 'expired' };
  const raw = await getRedis().get(key(email));
  if (!raw) return { ok: false, reason: 'expired' };
  const pending = JSON.parse(raw) as PendingReset;

  if (pending.attempts >= MAX_ATTEMPTS) {
    await dropPendingReset(email);
    return { ok: false, reason: 'too_many' };
  }
  if (hashOtp(otp.trim()) !== pending.otpHash) {
    // Count the miss but preserve the remaining TTL, so guessing can't also
    // be used to extend the window.
    const r = getRedis();
    const ttl = await r.ttl(key(email));
    pending.attempts += 1;
    await r.set(key(email), JSON.stringify(pending), 'EX', ttl > 0 ? ttl : TTL_S);
    return { ok: false, reason: 'invalid' };
  }
  return { ok: true };
}

/** Remaining resend cooldown in seconds (0 = allowed). */
export async function resetCooldownRemaining(email: string): Promise<number> {
  if (!redisAvailable()) return 0;
  const ttl = await getRedis().ttl(cooldownKey(email));
  return ttl > 0 ? ttl : 0;
}

export async function markResetSent(email: string): Promise<void> {
  if (!redisAvailable()) return;
  try {
    await getRedis().set(cooldownKey(email), '1', 'EX', RESEND_COOLDOWN_S);
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'password reset cooldown set failed');
  }
}
