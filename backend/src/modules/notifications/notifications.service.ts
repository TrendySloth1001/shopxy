import prisma from '../../infra/db/prisma.js';
import { Prisma } from '@prisma/client';

const notifSelect = {
  id: true,
  userId: true,
  kind: true,
  title: true,
  body: true,
  data: true,
  readAt: true,
  createdAt: true,
} satisfies Prisma.NotificationSelect;

export class NotificationsService {
  async list(opts: {
    userId: number;
    unreadOnly: boolean;
    skip: number;
    limit: number;
  }) {
    const where: Prisma.NotificationWhereInput = { userId: opts.userId };
    if (opts.unreadOnly) where.readAt = null;

    const [data, total, unread] = await Promise.all([
      prisma.notification.findMany({
        where,
        select: notifSelect,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.notification.count({ where }),
      prisma.notification.count({ where: { userId: opts.userId, readAt: null } }),
    ]);
    return { data, total, unread };
  }

  unreadCount(userId: number) {
    return prisma.notification.count({ where: { userId, readAt: null } });
  }

  async markRead(opts: { userId: number; notificationId: number }) {
    const result = await prisma.notification.updateMany({
      where: { id: opts.notificationId, userId: opts.userId, readAt: null },
      data: { readAt: new Date() },
    });
    return result.count > 0;
  }

  async create(opts: {
    userId: number;
    kind: string;
    title: string;
    body?: string;
    data?: Record<string, unknown>;
  }) {
    return prisma.notification.create({
      data: {
        userId: opts.userId,
        kind: opts.kind,
        title: opts.title,
        body: opts.body ?? null,
        data: (opts.data ?? Prisma.JsonNull) as Prisma.InputJsonValue,
      },
    });
  }

  async markAllRead(userId: number) {
    const result = await prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return result.count;
  }
}

export const notificationsService = new NotificationsService();
