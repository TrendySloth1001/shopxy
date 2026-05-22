import { Request, Response } from 'express';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { notificationsService } from './notifications.service.js';

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class NotificationsController {
  async list(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const unreadOnly = req.query.unreadOnly === 'true';
    const { data, total, unread } = await notificationsService.list({
      userId: req.user!.sub,
      unreadOnly,
      skip,
      limit,
    });
    const body = paginatedResponse(data, total, { page, limit, skip });
    res.json({ ...body, unread });
  }

  async unreadCount(req: Request, res: Response): Promise<void> {
    const count = await notificationsService.unreadCount(req.user!.sub);
    res.json({ unread: count });
  }

  async markRead(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    await notificationsService.markRead({ userId: req.user!.sub, notificationId: id });
    res.status(204).send();
  }

  async markAllRead(req: Request, res: Response): Promise<void> {
    const count = await notificationsService.markAllRead(req.user!.sub);
    res.json({ updated: count });
  }
}

export const notificationsController = new NotificationsController();
