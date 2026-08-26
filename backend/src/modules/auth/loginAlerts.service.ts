import { createHash } from 'crypto';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';
import { notificationsService } from '../notifications/notifications.service.js';
import { sendMail } from '../../infra/mailer.js';
import { maskIp, type DeviceContext } from './deviceContext.js';

export interface LoginContext extends DeviceContext {
  userId: number;
}

function fingerprint(userAgent?: string | null): string {
  return createHash('sha256').update(userAgent ?? 'unknown').digest('hex');
}

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
  async recordLogin(ctx: LoginContext): Promise<void> {
    try {
      const fp = fingerprint(ctx.userAgent);
      const ipMasked = maskIp(ctx.ip);

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

  async recentLogins(userId: number, limit = 20) {
    return prisma.loginEvent.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(limit, 50),
      select: { id: true, ipMasked: true, userAgent: true, createdAt: true },
    });
  },
};
