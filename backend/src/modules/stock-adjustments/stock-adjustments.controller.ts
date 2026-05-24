import { Request, Response } from 'express';
import { z } from 'zod';
import { ADJUSTMENT_REASONS, LEDGER_DIRECTIONS } from '../../shared/constants/index.js';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { stockAdjustmentsService } from './stock-adjustments.service.js';

const itemSchema = z.object({
  productId: z.number().int().positive(),
  quantity: z.number().positive(),
  unitCost: z.number().nonnegative().optional(),
  note: z.string().max(500).optional(),
});

const createSchema = z.object({
  reasonCode: z.enum(ADJUSTMENT_REASONS as unknown as [string, ...string[]]),
  direction: z.enum(LEDGER_DIRECTIONS).optional(),
  note: z.string().max(1000).optional(),
  items: z.array(itemSchema).min(1),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

function requireShopId(req: Request, res: Response): number | null {
  const shopId = req.user?.shopId;
  if (!shopId) {
    res.status(403).json({ error: 'This account has no shop linked.' });
    return null;
  }
  return shopId;
}

export class StockAdjustmentsController {
  async create(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const payload = createSchema.parse(req.body);
    const result = await stockAdjustmentsService.create(shopId, {
      reasonCode: payload.reasonCode as never,
      direction: payload.direction,
      note: payload.note,
      items: payload.items,
      createdById: req.user?.sub,
    });
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(201).json(result.adjustment);
  }

  async list(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { page, limit, skip } = parsePagination(req);
    const reasonCode = req.query.reasonCode as string | undefined;
    const { adjustments, total } = await stockAdjustmentsService.list(shopId, {
      reasonCode,
      page,
      limit,
      skip,
    });
    res.json(paginatedResponse(adjustments, total, { page, limit, skip }));
  }

  async getById(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const adjustment = await stockAdjustmentsService.getById(shopId, id);
    if (!adjustment) {
      res.status(404).json({ error: 'Adjustment not found' });
      return;
    }
    res.json(adjustment);
  }

  async reverse(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const result = await stockAdjustmentsService.reverse(shopId, id, {
      createdById: req.user?.sub,
      note: typeof req.body?.note === 'string' ? req.body.note : undefined,
    });
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json(result);
  }
}

export const stockAdjustmentsController = new StockAdjustmentsController();
