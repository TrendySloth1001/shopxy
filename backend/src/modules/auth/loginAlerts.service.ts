import { createHash } from 'crypto';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';
import { notificationsService } from '../notifications/notifications.service.js';
import { sendMail } from '../../infra/mailer.js';

/**
 * Login history + new-device alerting.
 *
 * On each successful login we record a {@link LoginEvent}. If the device
 * (fingerprint = SHA-256 of the user-agent) hasn't been seen for this user
 * before — and it isn't their very first login — we raise a security alert so
 * the real owner notices an unfamiliar sign-in.
 *
 * Delivery is **channel-agnostic**: an in-app notification, plus an out-of-band
 * email via {@link deliverOutOfBand} (the stronger signal for account takeover,
 * since it reaches the owner even if the attacker is the one in the app). The
 * email is best-effort and no-ops when SMTP isn't configured.
 */

export interface LoginContext {
  userId: number;
  ip?: string | null;
  userAgent?: string | null;
}

/** Coarse IP for a recognisable-but-not-precise history entry (drops the last octet / IPv6 tail). */
function maskIp(ip?: string | null): string | null {
  if (!ip) return null;
  const v = ip.replace(/^::ffff:/, '');
  if (v.includes('.')) return v.split('.').slice(0, 3).join('.') + '.x';
  if (v.includes(':')) return v.split(':').slice(0, 3).join(':') + ':…';
  return null;
}

function fingerprint(userAgent?: string | null): string {
  return createHash('sha256').update(userAgent ?? 'unknown').digest('hex');
}

/** Out-of-band new-device alert (email). Best-effort — the mailer no-ops if SMTP isn't set. */
async function deliverOutOfBand(email: string, ipMasked: string | null): Promise<void> {
  const where = ipMasked ? ` (around ${ipMasked})` : '';
  await sendMail({
    to: email,
    subject: 'New sign-in to your ShopXY account',
    text:
      `A new device just signed in to your ShopXY account${where}.\n\n` +
      `If this was you, you can ignore this email. If not, change your ` +
      `password and sign out of all devices immediately.`,
    html:
      `<p>A new device just signed in to your <b>ShopXY</b> account${where}.</p>` +
      `<p>If this was you, you can ignore this email. If not, ` +
      `<b>change your password and sign out of all devices</b> immediately.</p>`,
  });
}

export const loginAlertsService = {
  /**
   * Record a successful login and alert on a new device. Best-effort: never
   * throws into the login path — a logging/alerting hiccup must not fail auth.
   */
  async recordLogin(ctx: LoginContext): Promise<void> {
    try {
      const fp = fingerprint(ctx.userAgent);
      const ipMasked = maskIp(ctx.ip);

      // Two cheap indexed reads: has this exact device been seen, and has the
      // user ever logged in at all (so we don't alert on their first sign-in).
      const [seenDevice, priorCount] = await Promise.all([
        prisma.loginEvent.findFirst({
          where: { userId: ctx.userId, fingerprint: fp },
          select: { id: true },
        }),
        prisma.loginEvent.count({ where: { userId: ctx.userId } }),
      ]);

      await prisma.loginEvent.create({
        data: {
          userId: ctx.userId,
          fingerprint: fp,
          ipMasked,
          userAgent: ctx.userAgent?.slice(0, 400) ?? null,
        },
      });

      // New device, and not the account's first-ever login → alert the owner.
      if (!seenDevice && priorCount > 0) {
        await notificationsService.create({
          userId: ctx.userId,
          kind: 'SECURITY',
          title: 'New sign-in to your account',
          body: ipMasked
            ? `A new device just signed in (around ${ipMasked}). If this wasn't you, change your password and sign out everywhere.`
            : 'A new device just signed in. If this wasn’t you, change your password and sign out everywhere.',
          data: { event: 'new_device_login', ipMasked },
        });
        const owner = await prisma.user.findUnique({
          where: { id: ctx.userId },
          select: { email: true },
        });
        if (owner?.email) await deliverOutOfBand(owner.email, ipMasked);
      }
    } catch (err) {
      logger.warn({ err: (err as Error).message, userId: ctx.userId }, 'login-alerts: record failed');
    }
  },

  /** Recent sign-ins for the caller's "security" screen, newest first. */
  async recentLogins(userId: number, limit = 20) {
    return prisma.loginEvent.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 50),
      select: { id: true, ipMasked: true, userAgent: true, createdAt: true },
    });
  },
};
