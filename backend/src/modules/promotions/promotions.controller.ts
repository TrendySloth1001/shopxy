import { Request, Response } from 'express';
import { z } from 'zod';
import { promotionsService } from './promotions.service.js';

const createSchema = z
  .object({
    productId: z.number().int().positive(),
    budgetPaise: z.number().int().positive().max(100_000_000),
    dailyCapPaise: z.number().int().positive().max(100_000_000),
    cpmPaise: z.number().int().positive().max(1_000_000),
    startAt: z.string().datetime(),
    endAt: z.string().datetime(),
  })
  .refine((d) => new Date(d.endAt) > new Date(d.startAt), {
    message: 'endAt must be after startAt',
    path: ['endAt'],
  })
  .refine((d) => d.dailyCapPaise <= d.budgetPaise, {
    message: 'dailyCapPaise cannot exceed total budgetPaise',
    path: ['dailyCapPaise'],
  });

const updateSchema = z
  .object({
    budgetPaise: z.number().int().positive().max(100_000_000).optional(),
    dailyCapPaise: z.number().int().positive().max(100_000_000).optional(),
    cpmPaise: z.number().int().positive().max(1_000_000).optional(),
    startAt: z.string().datetime().optional(),
    endAt: z.string().datetime().optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, 'At least one field required');

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class PromotionsController {
  async list(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const data = await promotionsService.listForShop(shopId);
    res.json({ data });
  }

  async getOne(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const row = await promotionsService.getById(shopId, id);
    if (!row) {
      res.status(404).json({ error: 'Promotion not found' });
      return;
    }
    res.json(row);
  }

  async create(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const payload = createSchema.parse(req.body);
    try {
      const created = await promotionsService.create({
        shopId,
        productId: payload.productId,
        budgetPaise: payload.budgetPaise,
        dailyCapPaise: payload.dailyCapPaise,
        cpmPaise: payload.cpmPaise,
        startAt: new Date(payload.startAt),
        endAt: new Date(payload.endAt),
      });
      res.status(201).json(created);
    } catch (e) {
      const err = e as Error & { statusCode?: number };
      if (err.statusCode === 404) {
        res.status(404).json({ error: err.message });
        return;
      }
      throw err;
    }
  }

  async update(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateSchema.parse(req.body);
    const row = await promotionsService.update(shopId, id, {
      ...payload,
      startAt: payload.startAt ? new Date(payload.startAt) : undefined,
      endAt: payload.endAt ? new Date(payload.endAt) : undefined,
    });
    if (!row) {
      res.status(404).json({ error: 'Promotion not found' });
      return;
    }
    res.json(row);
  }

  async cancel(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await promotionsService.cancel(shopId, id);
    if (!ok) {
      res.status(404).json({ error: 'Promotion not found' });
      return;
    }
    res.status(204).send();
  }
}

export const promotionsController = new PromotionsController();
