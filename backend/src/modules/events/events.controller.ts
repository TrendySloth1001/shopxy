import { Request, Response } from 'express';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { ProductEventType } from '@prisma/client';
import { z } from 'zod';
import { eventsService, IncomingEvent } from './events.service.js';

const EVENT_TYPES: [ProductEventType, ...ProductEventType[]] = [
  'IMPRESSION',
  'TAP',
  'VIEW',
  'ADD_TO_CART',
  'PURCHASE',
  'WISHLIST_ADD',
];

const MAX_BATCH = 100;

const eventSchema = z.object({
  clientUuid: z.string().min(8).max(80),
  eventType: z.enum(EVENT_TYPES),
  productId: zPublicId,
  sessionId: z.string().max(80).nullable().optional(),
  source: z.string().max(40).nullable().optional(),
  meta: z.unknown().optional(),
  occurredAt: z.string().datetime(),
});

const batchSchema = z.object({
  events: z.array(eventSchema).min(1).max(MAX_BATCH),
});

export class EventsController {
  async ingest(req: Request, res: Response): Promise<void> {
    const { events } = batchSchema.parse(req.body);
    const userId = req.user!.sub;

    const incoming: IncomingEvent[] = events.map((e) => ({
      clientUuid: e.clientUuid,
      eventType: e.eventType,
      productId: e.productId,
      sessionId: e.sessionId,
      source: e.source,
      meta: e.meta,
      occurredAt: new Date(e.occurredAt),
    }));

    const result = await eventsService.ingest(incoming, userId);
    res.status(202).json(result);
  }

  async listRecentlyViewed(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const data = await eventsService.listRecentlyViewed(userId);
    res.json({ data });
  }
}

export const eventsController = new EventsController();
