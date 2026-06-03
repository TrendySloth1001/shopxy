import { Request, Response } from 'express';
import { z } from 'zod';
import { reportsService, DateRange } from './reports.service.js';

const rangeSchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

/// Default range = last 30 days. End-exclusive.
function parseRange(req: Request): DateRange {
  const parsed = rangeSchema.parse({ from: req.query.from, to: req.query.to });
  const now = new Date();
  const defaultFrom = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  return {
    from: parsed.from ? new Date(parsed.from) : defaultFrom,
    to: parsed.to ? new Date(parsed.to) : now,
  };
}

/// Every report is scoped to the caller's shop. resolveShop runs ahead of
/// this router and guarantees req.shopId is set; bail loudly if it isn't
/// rather than silently aggregating across every tenant (the old bug).
function requireShopId(req: Request, res: Response): number | null {
  if (typeof req.shopId !== 'number') {
    res.status(403).json({ error: 'This account has no shop linked.' });
    return null;
  }
  return req.shopId;
}

export class ReportsController {
  async sales(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const data = await reportsService.sales(shopId, parseRange(req));
    res.json(data);
  }
  async purchases(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const data = await reportsService.purchases(shopId, parseRange(req));
    res.json(data);
  }
  async gst(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const data = await reportsService.gstSummary(shopId, parseRange(req));
    res.json(data);
  }
  async pnl(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const data = await reportsService.pnl(shopId, parseRange(req));
    res.json(data);
  }
}

export const reportsController = new ReportsController();
