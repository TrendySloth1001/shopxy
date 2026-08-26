import { Request, Response } from 'express';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { decodeId } from '../../shared/ids/publicId.js';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { quotationsService, QuotationStatus } from './quotations.service.js';

const itemSchema = z.object({
  productId: zPublicId,
  name: z.string().max(200),
  sku: z.string().max(120).nullable().optional(),
  quantity: z.number().positive(),
  unitPrice: z.number().nonnegative(),
  taxPercent: z.number().min(0).max(100).nullable().optional(),
  cessRate: z.number().min(0).max(100).nullable().optional(),
  discount: z.number().nonnegative().nullable().optional(),
  imageUrl: z.string().max(2000).nullable().optional(),
});

const createSchema = z.object({
  partyId: zPublicId,
  items: z.array(itemSchema).min(1).max(100),
  note: z.string().max(500).nullable().optional(),
  placeOfSupplyStateCode: z.string().max(2).nullable().optional(),
});

const statusSchema = z
  .enum(['REQUESTED', 'PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED'])
  .optional();

const respondSchema = z.object({
  items: z.array(itemSchema).min(1).max(100),
  note: z.string().max(500).nullable().optional(),
  placeOfSupplyStateCode: z.string().max(2).nullable().optional(),
});

const declineRequestSchema = z.object({
  declineNote: z.string().max(500).nullable().optional(),
});

function parseId(raw: string): number | null {
  return decodeId(raw);
}

function requireShopId(req: Request, res: Response): number | null {
  const shopId = req.user?.shopId;
  if (!shopId) {
    res.status(403).json({ error: 'This account has no shop linked.' });
    return null;
  }
  return shopId;
}

export class QuotationsController {
  async create(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const payload = createSchema.parse(req.body);
    const result = await quotationsService.create(
      shopId,
      payload.partyId,
      req.user!.sub,
      {
        items: payload.items,
        note: payload.note,
        placeOfSupplyStateCode: payload.placeOfSupplyStateCode,
      },
    );
    if ('error' in result) {
      const msg = result.error === 'PARTY_NOT_LINKED'
        ? 'This customer is not linked to the app, so they can’t receive a quotation.'
        : 'Party not found';
      res.status(result.error === 'PARTY_NOT_LINKED' ? 400 : 404).json({
        code: result.error,
        error: msg,
      });
      return;
    }
    res.status(201).json(result.quotation);
  }

  async list(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { page, limit, skip } = parsePagination(req);
    const status = statusSchema.parse(req.query.status) as QuotationStatus | undefined;
    const { data, total } = await quotationsService.listForShop(shopId, {
      status,
      archived: req.query.archived === 'true',
      skip,
      take: limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async getById(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const quotation = await quotationsService.getForShop(shopId, id);
    if (!quotation) { res.status(404).json({ error: 'Quotation not found' }); return; }
    res.json(quotation);
  }

  async cancel(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const quotation = await quotationsService.cancel(shopId, id);
    res.json(quotation);
  }

  async archive(req: Request, res: Response): Promise<void> {
    await this.setArchived(req, res, true);
  }

  async unarchive(req: Request, res: Response): Promise<void> {
    await this.setArchived(req, res, false);
  }

  private async setArchived(
    req: Request,
    res: Response,
    archived: boolean,
  ): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const result = await quotationsService.setArchived(shopId, id, archived);
    if ('error' in result) { res.status(400).json({ error: result.error }); return; }
    res.json(result.quotation);
  }

  async respond(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = respondSchema.parse(req.body);
    const quotation = await quotationsService.respondToRequest(
      shopId,
      id,
      req.user!.sub,
      {
        items: payload.items,
        note: payload.note,
        placeOfSupplyStateCode: payload.placeOfSupplyStateCode,
      },
    );
    res.json(quotation);
  }

  async downloadPdf(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const quotation = await quotationsService.getForShop(shopId, id);
    if (!quotation) { res.status(404).json({ error: 'Quotation not found' }); return; }
    const filename = `quotation-${quotation.quotationNo ?? id}.pdf`;
    const err = await quotationsService.streamPdf(shopId, id, res, () => {
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    });
    if (err) {
      if (!res.headersSent) res.status(500).json({ error: err.error });
      else res.end();
    }
  }

  async declineRequest(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const { declineNote } = declineRequestSchema.parse(req.body ?? {});
    const quotation = await quotationsService.declineRequest(shopId, id, declineNote);
    res.json(quotation);
  }
}

export const quotationsController = new QuotationsController();
