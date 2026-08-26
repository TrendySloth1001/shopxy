import { createHash, randomInt } from 'crypto';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';
import { sendMail, mailerEnabled } from '../../infra/mailer.js';

export interface PendingRegistration {
  name: string;
  email: string;
  passwordHash: string;
  role: 'OWNER' | 'CUSTOMER';
  shopName?: string;
  otpHash: string;
  attempts: number;
}

const TTL_S = 15 * 60;
const MAX_ATTEMPTS = 5;
const RESEND_COOLDOWN_S = 30;

const key = (email: string) => `pendreg:${createHash('sha256').update(email).digest('hex')}`;
const cooldownKey = (email: string) => `pendreg:cd:${createHash('sha256').update(email).digest('hex')}`;

function hashOtp(otp: string): string {
  return createHash('sha256').update(otp).digest('hex');
}

export function generateOtp(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, '0');
}

export function canVerifyEmail(): boolean {
  return redisAvailable() && mailerEnabled();
}

export async function sendOtpEmail(email: string, name: string, otp: string): Promise<boolean> {
  return sendMail({
    category: 'otp',
    to: email,
    subject: `${otp} is your ShopXY verification code`,
    text:
      `Hi ${name || 'there'},\n\n` +
      `Your ShopXY verification code is ${otp}. It expires in 15 minutes.\n\n` +
      `If you didn't try to create a ShopXY account, you can ignore this email.`,
    html:
      `<p>Hi ${name || 'there'},</p>` +
      `<p>Your ShopXY verification code is:</p>` +
      `<p style="font-size:28px;font-weight:700;letter-spacing:4px">${otp}</p>` +
      `<p>It expires in 15 minutes. If you didn't try to create a ShopXY account, ignore this email.</p>`,
  });
}

export async function putPending(
  p: Omit<PendingRegistration, 'attempts' | 'otpHash'>,
  otp: string,
): Promise<void> {
  const record: PendingRegistration = { ...p, otpHash: hashOtp(otp), attempts: 0 };
  await getRedis().set(key(p.email), JSON.stringify(record), 'EX', TTL_S);
}

export async function getPending(email: string): Promise<PendingRegistration | null> {
  if (!redisAvailable()) return null;
  const raw = await getRedis().get(key(email));
  return raw ? (JSON.parse(raw) as PendingRegistration) : null;
}

export async function dropPending(email: string): Promise<void> {
  if (!redisAvailable()) return;
  await getRedis().del(key(email));
}

export async function verifyOtp(
  email: string,
  otp: string,
): Promise<
  | { ok: true; pending: PendingRegistration }
  | { ok: false; reason: 'expired' | 'invalid' | 'too_many' }
> {
  const pending = await getPending(email);
  if (!pending) return { ok: false, reason: 'expired' };
  if (pending.attempts >= MAX_ATTEMPTS) {
    await dropPending(email);
    return { ok: false, reason: 'too_many' };
  }
  if (hashOtp(otp.trim()) !== pending.otpHash) {
    const r = getRedis();
    const ttl = await r.ttl(key(email));
    pending.attempts += 1;
    await r.set(key(email), JSON.stringify(pending), 'EX', ttl > 0 ? ttl : TTL_S);
    return { ok: false, reason: 'invalid' };
  }
  return { ok: true, pending };
}

export async function resendCooldownRemaining(email: string): Promise<number> {
  if (!redisAvailable()) return 0;
  const ttl = await getRedis().ttl(cooldownKey(email));
  return ttl > 0 ? ttl : 0;
}

export async function markResent(email: string): Promise<void> {
  if (!redisAvailable()) return;
  try {
    await getRedis().set(cooldownKey(email), '1', 'EX', RESEND_COOLDOWN_S);
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'otp resend cooldown set failed');
  }
}
