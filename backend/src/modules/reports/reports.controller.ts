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

export class ReportsController {
  async sales(req: Request, res: Response): Promise<void> {
    const range = parseRange(req);
    const data = await reportsService.sales(range);
    res.json(data);
  }
  async purchases(req: Request, res: Response): Promise<void> {
    const range = parseRange(req);
    const data = await reportsService.purchases(range);
    res.json(data);
  }
  async gst(req: Request, res: Response): Promise<void> {
    const range = parseRange(req);
    const data = await reportsService.gstSummary(range);
    res.json(data);
  }
  async pnl(req: Request, res: Response): Promise<void> {
    const range = parseRange(req);
    const data = await reportsService.pnl(range);
    res.json(data);
  }
}

export const reportsController = new ReportsController();
