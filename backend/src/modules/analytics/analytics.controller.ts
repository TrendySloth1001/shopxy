import { Request, Response } from 'express';
import { decodeId } from '../../shared/ids/publicId.js';
import { z } from 'zod';
import {
  analyticsService,
  clampAnalyticsLimit,
  parseAnalyticsCursor,
  ANALYTICS_MAX_ESTIMATED_ROWS,
} from './analytics.service.js';

const rangeSchema = z
  .object({
    from: z.string().datetime().optional(),
    to: z.string().datetime().optional(),
    limit: z.union([z.string(), z.number()]).optional(),
    cursor: z.string().optional(),
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
  return decodeId(raw);
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

    // Bound the request before issuing the aggregate. The estimate is
    // the count of active products in the shop — a tight upper bound
    // on the rowset since the aggregate groups by product.
    const estimatedRows = await analyticsService.estimateProductRows(shopId);
    if (estimatedRows > ANALYTICS_MAX_ESTIMATED_ROWS) {
      res.status(400).json({
        error: 'range_too_large',
        estimatedRows,
        maxEstimatedRows: ANALYTICS_MAX_ESTIMATED_ROWS,
      });
      return;
    }

    const limit = clampAnalyticsLimit(parsed.limit);
    const cursorProductId = parseAnalyticsCursor(parsed.cursor);
    const data = await analyticsService.getProductAnalytics(shopId, from, to, {
      limit,
      cursorProductId,
    });
    res.json(data);
  }

  async heatmap(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const parsed = rangeSchema.parse(req.query);
    const { from, to } = resolveRange(parsed);
    if (to.getTime() - from.getTime() > MAX_RANGE_DAYS * 86_400_000) {
      res.status(400).json({ error: `Date range > ${MAX_RANGE_DAYS} days` });
      return;
    }
    res.json(await analyticsService.getPurchaseHeatmap(shopId, from, to));
  }

  async customers(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const parsed = rangeSchema.parse(req.query);
    const { from, to } = resolveRange(parsed);
    if (to.getTime() - from.getTime() > MAX_RANGE_DAYS * 86_400_000) {
      res.status(400).json({ error: `Date range > ${MAX_RANGE_DAYS} days` });
      return;
    }
    res.json(await analyticsService.getCustomerRetention(shopId, from, to));
  }
}

export const analyticsController = new AnalyticsController();
