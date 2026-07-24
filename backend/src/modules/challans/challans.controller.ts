import { Request, Response } from 'express';
import { decodeId } from '../../shared/ids/publicId.js';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { z } from 'zod';
import { challansService } from './challans.service.js';

// CWQ-11 — bound the per-line quantity. The column is Decimal(12,3), so a
// value at or above 1e9 (or with finer than milli-unit precision) cannot be
// stored faithfully; an absurd quantity is also a typo guard before the line
// hits the stock ledger. Fractional quantities stay allowed (some units are
// sold by weight/length), but capped to the column's 3-decimal resolution.
const challanItemSchema = z.object({
  productId: zPublicId,
  quantity: z
    .number()
    .positive()
    .lt(1_000_000_000)
    .refine((q) => Number.isFinite(q) && Math.round(q * 1000) === q * 1000, {
      message: 'Quantity supports at most 3 decimal places',
    }),
});

const createChallanSchema = z
  .object({
    partyId: zPublicId.optional(),
    partyName: z.string().min(1).optional(),
    partyPhone: z.string().optional(),
    note: z.string().optional(),
    items: z.array(challanItemSchema).min(1),
  })
  .refine((d) => d.partyId !== undefined || (d.partyName && d.partyName.length > 0), {
    message: 'Either partyId or partyName is required',
    path: ['partyName'],
  });

const convertSchema = z.object({
  customerName: z.string().optional(),
  customerGstin: z.string().optional(),
  discount: z.number().min(0).optional(),
  note: z.string().optional(),
});

function requireShopId(req: Request, res: Response): number | null {
  const shopId = req.user?.shopId;
  if (!shopId) {
    res.status(403).json({ error: 'This account has no shop linked.' });
    return null;
  }
  return shopId;
}

export async function createChallan(req: Request, res: Response) {
  const shopId = requireShopId(req, res);
  if (!shopId) return;
  const parsed = createChallanSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await challansService.createChallan(shopId, {
    ...parsed.data,
    createdById: req.user?.sub,
  });
  if ('error' in result) {
    res.status(400).json({
      error: result.error,
      ...('productId' in result
        ? { productId: result.productId, available: result.available, requested: result.requested }
        : {}),
    });
    return;
  }
  res.status(201).json(result.challan);
}

export async function listChallans(req: Request, res: Response) {
  const shopId = requireShopId(req, res);
  if (!shopId) return;
  const status = typeof req.query.status === 'string' ? req.query.status : undefined;
  const search = typeof req.query.search === 'string' ? req.query.search : '';
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 20));
  const skip = (page - 1) * limit;

  const { challans, total } = await challansService.listChallans(shopId, { status, search, page, limit, skip });
  res.json({ data: challans, pagination: { total, page, limit } });
}

export async function getChallan(req: Request, res: Response) {
  const shopId = requireShopId(req, res);
  if (!shopId) return;
  const id = decodeId(req.params.id);
  if (id === null) {
    res.status(404).json({ error: 'Challan not found' });
    return;
  }
  const challan = await challansService.getChallanById(shopId, id);
  if (!challan) {
    res.status(404).json({ error: 'Challan not found' });
    return;
  }
  res.json(challan);
}

export async function cancelChallan(req: Request, res: Response) {
  const shopId = requireShopId(req, res);
  if (!shopId) return;
  const id = decodeId(req.params.id);
  if (id === null) {
    res.status(404).json({ error: 'Challan not found' });
    return;
  }
  const result = await challansService.cancelChallan(shopId, id, req.user?.sub);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(204).end();
}

export async function downloadChallanPdf(req: Request, res: Response) {
  const shopId = requireShopId(req, res);
  if (!shopId) return;
  const id = decodeId(req.params.id);
  if (id === null) {
    res.status(400).json({ error: 'Invalid id' });
    return;
  }

  // Look up once so we can 404 before streaming headers and name the download.
  const challan = await challansService.getChallanById(shopId, id);
  if (!challan) {
    res.status(404).json({ error: 'Challan not found' });
    return;
  }
  const filename = `challan-${challan.challanNo ?? id}.pdf`;

  // onReady fires only after the renderer re-verifies the challan and right
  // before bytes flow, so a late error still yields a clean JSON 5xx.
  const err = await challansService.streamPdf(shopId, id, res, () => {
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
  });
  if (err) {
    if (!res.headersSent) {
      res.status(500).json({ error: err.error });
    } else {
      res.end();
    }
  }
}

export async function convertToInvoice(req: Request, res: Response) {
  const shopId = requireShopId(req, res);
  if (!shopId) return;
  const id = decodeId(req.params.id);
  if (id === null) {
    res.status(404).json({ error: 'Challan not found' });
    return;
  }
  const parsed = convertSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await challansService.convertToInvoice(shopId, id, parsed.data);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(201).json(result.invoice);
}
