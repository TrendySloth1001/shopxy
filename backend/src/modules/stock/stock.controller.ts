import { Request, Response } from 'express';
import { z } from 'zod';
import { STOCK_TRANSACTION_TYPES } from '../../shared/constants/index.js';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { stockService } from './stock.service.js';

const createTransactionSchema = z.object({
  productId: z.number().int().positive(),
  type: z.enum(STOCK_TRANSACTION_TYPES),
  quantity: z.number().positive(),
  unitPrice: z.number().nonnegative().optional(),
  note: z.string().max(500).optional(),
});

export class StockController {
  async createTransaction(req: Request, res: Response): Promise<void> {
    const payload = createTransactionSchema.parse(req.body);
    const result = await stockService.createTransaction(payload);

    if ('error' in result) {
      if (result.error === 'Product not found') {
        res.status(404).json({ error: 'Product not found' });
        return;
      }

      res.status(400).json({
        error: result.error,
        available: result.available,
        requested: result.requested,
      });
      return;
    }

    res.status(201).json(result.transaction);
  }

  async listTransactions(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const productId = req.query.productId ? Number(req.query.productId) : undefined;
    const type = req.query.type as string | undefined;

    const { transactions, total } = await stockService.listTransactions({
      productId,
      type:
        type && STOCK_TRANSACTION_TYPES.includes(type as (typeof STOCK_TRANSACTION_TYPES)[number])
          ? type
          : undefined,
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(transactions, total, { page, limit, skip }));
  }
}

export const stockController = new StockController();
