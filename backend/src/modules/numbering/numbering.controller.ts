import { Request, Response } from 'express';
import { z } from 'zod';
import { ALL_SERIES, type Series } from '../../shared/numbering/sequences.js';
import { numberingService } from './numbering.service.js';

const SERIES_VALUES = ALL_SERIES as readonly [Series, ...Series[]];

const CODE_RE = /^[A-Za-z0-9\-_.]*$/;

const schemeSchema = z
  .object({
    prefix: z.string().max(10).regex(CODE_RE, 'Only letters, numbers, - _ . allowed').optional(),
    suffix: z.string().max(10).regex(CODE_RE, 'Only letters, numbers, - _ . allowed').optional(),
    separator: z.enum(['/', '-', '.', '']).optional(),
    padding: z.number().int().min(1).max(8).optional(),
    resetYearly: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, { message: 'At least one field is required' });

const nextNumberSchema = z.object({
  startAt: z.number().int().positive(),
});

function requireShopId(req: Request, res: Response): number | null {
  const shopId = req.user?.shopId;
  if (!shopId) {
    res.status(403).json({ error: 'This account has no shop linked.' });
    return null;
  }
  return shopId;
}

function parseSeries(req: Request, res: Response): Series | null {
  const raw = req.params.series;
  if (!SERIES_VALUES.includes(raw as Series)) {
    res.status(400).json({ error: 'Invalid series' });
    return null;
  }
  return raw as Series;
}

export class NumberingController {
  async list(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const schemes = await numberingService.listSchemesForShop(shopId);
    res.json(schemes);
  }

  async upsert(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const series = parseSeries(req, res);
    if (!series) return;
    const payload = schemeSchema.parse(req.body);
    const scheme = await numberingService.upsertScheme(shopId, series, payload);
    res.json(scheme);
  }

  async setNextNumber(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const series = parseSeries(req, res);
    if (!series) return;
    const { startAt } = nextNumberSchema.parse(req.body);
    const scheme = await numberingService.setNextNumber(shopId, series, startAt);
    res.json(scheme);
  }
}

export const numberingController = new NumberingController();
