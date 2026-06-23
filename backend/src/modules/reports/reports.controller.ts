import { Request, Response } from 'express';
import { z } from 'zod';
import { reportsService, DateRange } from './reports.service.js';

const rangeSchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

/// India Standard Time offset (UTC+5:30) in milliseconds. The reports'
/// daily/GST buckets are computed with `AT TIME ZONE 'Asia/Kolkata'`, so
/// the WHERE window has to align to the SAME IST calendar boundaries —
/// otherwise an edge-of-day sale (e.g. IST 23:30 = UTC 18:00) can fall
/// in/out of the window inconsistently with its IST day bucket, and a
/// GSTR period (filed on the IST calendar month) won't tie to the books.
/// IST has no DST so a fixed offset is exact (AUTH-TR-M1).
const IST_OFFSET_MS = (5 * 60 + 30) * 60 * 1000;

/// Snap a UTC instant DOWN to the start of its IST calendar day, returned
/// as the UTC instant of that IST midnight. Keeps the WHERE window on the
/// same IST day boundaries the daily/GST buckets use.
function istDayStart(d: Date): Date {
  const istMs = d.getTime() + IST_OFFSET_MS;
  const dayMs = 24 * 60 * 60 * 1000;
  const istMidnight = Math.floor(istMs / dayMs) * dayMs;
  return new Date(istMidnight - IST_OFFSET_MS);
}

/// Max queryable window. The report aggregates are indexed scalar
/// aggregates (not row-returning), so an unbounded multi-year range is a
/// slow-query / p95 risk rather than a memory blow-up — but still cap it,
/// consistent with analytics' range guard (AUTH-TR-L1).
const MAX_RANGE_DAYS = 366;

class RangeTooLarge extends Error {}

/// Default range = last 30 days. End-exclusive. Both bounds are snapped to
/// IST day boundaries so the WHERE filter and the IST `date_trunc` buckets
/// agree on every edge-of-day / edge-of-month invoice.
function parseRange(req: Request): DateRange {
  const parsed = rangeSchema.parse({ from: req.query.from, to: req.query.to });
  const now = new Date();
  const defaultFrom = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  // `from` snaps DOWN to its IST midnight; `to` snaps to the START of the
  // IST day AFTER the requested instant so the (exclusive) upper bound
  // includes the whole requested end-day in IST.
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

/// Resolve the range, translating the too-large guard into a 400. Returns
/// null (after responding) when the window is rejected.
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
}

export const reportsController = new ReportsController();
