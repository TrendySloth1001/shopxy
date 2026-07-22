import { createHash } from 'crypto';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';
import { notificationsService } from '../notifications/notifications.service.js';

/**
 * Login history + new-device alerting.
 *
 * On each successful login we record a {@link LoginEvent}. If the device
 * (fingerprint = SHA-256 of the user-agent) hasn't been seen for this user
 * before — and it isn't their very first login — we raise a security alert so
 * the real owner notices an unfamiliar sign-in.
 *
 * Delivery is **channel-agnostic**: today it writes an in-app notification.
 * Out-of-band delivery (email / push) is the stronger signal for account
 * takeover but needs a mail/push transport that doesn't exist yet — it slots
 * into {@link deliverOutOfBand} without touching detection, so it's a drop-in
 * once that transport lands.
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

// Placeholder for a future mail/push transport. Intentionally a no-op today.
async function deliverOutOfBand(_ctx: LoginContext, _ipMasked: string | null): Promise<void> {
  // TODO: send email/push here once a transport exists — same call site,
  // no change to detection.
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
        await deliverOutOfBand(ctx, ipMasked);
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
