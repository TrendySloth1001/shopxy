import { Request, Response } from 'express';
import { z } from 'zod';
import { decodeId } from '../../shared/ids/publicId.js';
import { reportsService, DateRange } from './reports.service.js';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';

const rangeSchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;

function istDayStart(d: Date): Date {
  const istMs = d.getTime() + IST_OFFSET_MS;
  const dayMs = 24 * 60 * 60 * 1000;
  const istMidnight = Math.floor(istMs / dayMs) * dayMs;
  return new Date(istMidnight - IST_OFFSET_MS);
}

const MAX_RANGE_DAYS = 366;

class RangeTooLarge extends Error {}

function parseRange(req: Request): DateRange {
  const parsed = rangeSchema.parse({ from: req.query.from, to: req.query.to });
  const now = new Date();
  const defaultFrom = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const fromRaw = parsed.from ? new Date(parsed.from) : defaultFrom;
  const toRaw = parsed.to ? new Date(parsed.to) : now;
  const from = istDayStart(fromRaw);
  const dayMs = 24 * 60 * 60 * 1000;
  const to = new Date(istDayStart(toRaw).getTime() + dayMs);
  if (to.getTime() - from.getTime() > MAX_RANGE_DAYS * dayMs) {
    throw new RangeTooLarge(`Date range exceeds ${MAX_RANGE_DAYS} days`);
  }
  return { from, to };
}

function resolveRange(req: Request, res: Response): DateRange | null {
  try {
    return parseRange(req);
  } catch (err) {
    if (err instanceof RangeTooLarge) {
      res.status(400).json({ error: err.message, maxRangeDays: MAX_RANGE_DAYS });
      return null;
    }
    throw err;
  }
}

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
    const range = resolveRange(req, res);
    if (range === null) return;
    const data = await reportsService.sales(shopId, range);
    res.json(data);
  }
  async purchases(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const range = resolveRange(req, res);
    if (range === null) return;
    const data = await reportsService.purchases(shopId, range);
    res.json(data);
  }
  async gst(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const range = resolveRange(req, res);
    if (range === null) return;
    const data = await reportsService.gstSummary(shopId, range);
    res.json(data);
  }
  async pnl(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const range = resolveRange(req, res);
    if (range === null) return;
    const data = await reportsService.pnl(shopId, range);
    res.json(data);
  }
  async soldProducts(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const range = resolveRange(req, res);
    if (range === null) return;
    const params = parsePagination(req);
    const search = typeof req.query.search === 'string' ? req.query.search : undefined;
    const { items, total, totals } = await reportsService.soldProducts(shopId, range, {
      ...params,
      search,
    });
    res.json({ ...paginatedResponse(items, total, params), totals });
  }
  async soldItems(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (shopId === null) return;
    const range = resolveRange(req, res);
    if (range === null) return;
    const params = parsePagination(req);
    const search = typeof req.query.search === 'string' ? req.query.search : undefined;
    const productId = decodeId(req.query.productId as string | undefined) ?? undefined;
    const { items, total } = await reportsService.soldItems(shopId, range, {
      ...params,
      search,
      productId,
    });
    res.json(paginatedResponse(items, total, params));
  }
}

export const reportsController = new ReportsController();
