import { Request, Response } from 'express';
import { z } from 'zod';
import { flashSalesService } from './flash-sales.service.js';

const createSchema = z.object({
  productId: z.number().int().positive(),
  flashPrice: z.number().nonnegative(),
  stockLimit: z.number().int().positive(),
  startAt: z.string().datetime(),
  endAt: z.string().datetime(),
});

const updateSchema = z
  .object({
    flashPrice: z.number().nonnegative().optional(),
    stockLimit: z.number().int().positive().optional(),
    startAt: z.string().datetime().optional(),
    endAt: z.string().datetime().optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

const statusSchema = z.enum(['active', 'scheduled', 'past', 'all']);

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class FlashSalesController {
  // ── Merchant scope ────────────────────────────────────────────────

  async list(req: Request, res: Response): Promise<void> {
    const statusRaw = req.query.status as string | undefined;
    const status = statusRaw ? statusSchema.parse(statusRaw) : undefined;
    const rows = await flashSalesService.listForShop(req.shopId!, { status });
    res.json({ data: rows });
  }

  async getOne(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const row = await flashSalesService.getById(req.shopId!, id);
    if (!row) {
      res.status(404).json({ error: 'Flash sale not found' });
      return;
    }
    res.json(row);
  }

  async create(req: Request, res: Response): Promise<void> {
    const payload = createSchema.parse(req.body);
    const result = await flashSalesService.create(req.shopId!, {
      productId: payload.productId,
      flashPrice: payload.flashPrice,
      stockLimit: payload.stockLimit,
      startAt: new Date(payload.startAt),
      endAt: new Date(payload.endAt),
    });
    if ('error' in result) {
      switch (result.error) {
        case 'product_not_in_shop':
          res.status(404).json({ error: 'Product not found in your shop' });
          return;
        case 'invalid_window':
          res.status(400).json({ error: 'End time must be after start time' });
          return;
        case 'invalid_stock_limit':
          res.status(400).json({ error: 'Stock limit must be positive' });
          return;
        case 'invalid_price':
          res.status(400).json({ error: 'Flash price must be non-negative' });
          return;
        case 'active_sale_exists':
          res.status(409).json({
            error:
              'This product already has an active flash sale — cancel it first',
          });
          return;
      }
    }
    res.status(201).json(result.sale);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateSchema.parse(req.body);
    const result = await flashSalesService.update(req.shopId!, id, {
      ...(payload.flashPrice !== undefined && { flashPrice: payload.flashPrice }),
      ...(payload.stockLimit !== undefined && { stockLimit: payload.stockLimit }),
      ...(payload.startAt !== undefined && { startAt: new Date(payload.startAt) }),
      ...(payload.endAt !== undefined && { endAt: new Date(payload.endAt) }),
      ...(payload.isActive !== undefined && { isActive: payload.isActive }),
    });
    if (result === null) {
      res.status(404).json({ error: 'Flash sale not found' });
      return;
    }
    if ('error' in result) {
      res.status(400).json({ error: 'End time must be after start time' });
      return;
    }
    res.json(result.sale);
  }

  async cancel(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const result = await flashSalesService.cancel(req.shopId!, id);
    if (result === null) {
      res.status(404).json({ error: 'Flash sale not found' });
      return;
    }
    res.status(204).send();
  }

  // ── Public ────────────────────────────────────────────────────────

  async listPublic(req: Request, res: Response): Promise<void> {
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const data = await flashSalesService.listActivePublic({ limit });
    res.json({ data });
  }
}

export const flashSalesController = new FlashSalesController();
