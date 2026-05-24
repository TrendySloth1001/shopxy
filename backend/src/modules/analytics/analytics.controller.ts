import { Request, Response } from 'express';
import { z } from 'zod';
import { analyticsService } from './analytics.service.js';

const rangeSchema = z
  .object({
    from: z.string().datetime().optional(),
    to: z.string().datetime().optional(),
  })
  .refine(
    (d) => !d.from || !d.to || new Date(d.to) > new Date(d.from),
    'to must be after from',
  );

const DEFAULT_RANGE_DAYS = 7;
const MAX_RANGE_DAYS = 90;

function resolveRange(query: { from?: string; to?: string }): { from: Date; to: Date } {
  const to = query.to ? new Date(query.to) : new Date();
  const from = query.from
    ? new Date(query.from)
    : new Date(to.getTime() - DEFAULT_RANGE_DAYS * 86_400_000);
  return { from, to };
}

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class AnalyticsController {
  async products(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const parsed = rangeSchema.parse(req.query);
    const { from, to } = resolveRange(parsed);
    if (to.getTime() - from.getTime() > MAX_RANGE_DAYS * 86_400_000) {
      res.status(400).json({ error: `Date range > ${MAX_RANGE_DAYS} days` });
      return;
    }
    const data = await analyticsService.getProductAnalytics(shopId, from, to);
    res.json(data);
  }

  async flashDeal(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const data = await analyticsService.getFlashDealAnalytics(shopId, id);
    if (!data) {
      res.status(404).json({ error: 'Flash deal not found' });
      return;
    }
    res.json(data);
  }
}

export const analyticsController = new AnalyticsController();
