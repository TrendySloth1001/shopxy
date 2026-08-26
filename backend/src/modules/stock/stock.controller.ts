import { Request, Response } from 'express';
import { z } from 'zod';
import {
  STOCK_TRANSACTION_TYPES,
  LEDGER_REASON_CODES,
  LEDGER_DIRECTIONS,
  LEDGER_SOURCE_TYPES,
} from '../../shared/constants/index.js';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { decodeId } from '../../shared/ids/publicId.js';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { stockService } from './stock.service.js';

const createTransactionSchema = z.object({
  productId: zPublicId,
  type: z.enum(['STOCK_IN', 'STOCK_OUT']),
  quantity: z.number().positive(),
  unitPrice: z.number().nonnegative().optional(),
  vendorId: zPublicId.optional(),
  partyId: zPublicId.optional(),
  note: z.string().max(500).optional(),
});

const listSuppliersQuerySchema = z.object({
  q: z.string().trim().max(120).optional(),
  productId: zPublicId.optional(),
  limit: z.coerce.number().int().min(1).max(50).optional(),
});

function requireShopId(req: Request, res: Response): number | null {
  const shopId = req.user?.shopId;
  if (!shopId) {
    res.status(403).json({ error: 'This account has no shop linked.' });
    return null;
  }
  return shopId;
}

export class StockController {
  async createTransaction(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const payload = createTransactionSchema.parse(req.body);
    const result = await stockService.createTransaction(shopId, {
      ...payload,
      createdById: req.user?.sub,
    });

    if ('error' in result) {
      if (result.error === 'Product not found') {
        res.status(404).json({ error: 'Product not found' });
        return;
      }
      res.status(400).json({ error: result.error });
      return;
    }

    res.status(201).json({ draftInvoice: result.draftInvoice });
  }

  async listTransactions(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { page, limit, skip } = parsePagination(req);
    const productId = decodeId(req.query.productId as string | undefined) ?? undefined;
    const type = req.query.type as string | undefined;
    const direction = req.query.direction as string | undefined;
    const reasonCode = req.query.reasonCode as string | undefined;
    const sourceType = req.query.sourceType as string | undefined;
    const sourceId = decodeId(req.query.sourceId as string | undefined) ?? undefined;

    const { transactions, total } = await stockService.listTransactions(shopId, {
      productId,
      type:
        type && STOCK_TRANSACTION_TYPES.includes(type as (typeof STOCK_TRANSACTION_TYPES)[number])
          ? type
          : undefined,
      direction:
        direction && (LEDGER_DIRECTIONS as readonly string[]).includes(direction)
          ? direction
          : undefined,
      reasonCode:
        reasonCode && (LEDGER_REASON_CODES as readonly string[]).includes(reasonCode)
          ? reasonCode
          : undefined,
      sourceType:
        sourceType && (LEDGER_SOURCE_TYPES as readonly string[]).includes(sourceType)
          ? sourceType
          : undefined,
      sourceId: sourceId && Number.isFinite(sourceId) && sourceId > 0 ? sourceId : undefined,
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(transactions, total, { page, limit, skip }));
  }

  async listSuppliers(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const query = listSuppliersQuerySchema.parse(req.query);

    const { vendors, freeTextSuppliers } = await stockService.listSuppliers(shopId, {
      query: query.q,
      productId: query.productId,
      limit: query.limit ?? 12,
    });

    res.json({ vendors, freeTextSuppliers });
  }
}

export const stockController = new StockController();
