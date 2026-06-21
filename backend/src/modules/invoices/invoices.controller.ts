import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { invoicesService } from './invoices.service.js';

const itemSchema = z
  .object({
    productId: z.number().int().positive(),
    quantity: z.number().positive(),
    unitPrice: z.number().nonnegative(),
    taxPercent: z.number().min(0).max(100).optional(),
    /// GST compensation cess. Most line items leave this at 0; tobacco /
    /// luxury goods / aerated drinks attract it.
    cessRate: z.number().min(0).max(100).optional(),
    discount: z.number().nonnegative().optional(),
    /// GST-5 — per-line tax convention. Omitted ⇒ inherit the invoice-wide
    /// default (which itself defaults to EXCLUSIVE). When true the unit price
    /// is treated as tax-INCLUSIVE and the engine backs the tax out.
    isPriceInclusive: z.boolean().optional(),
  })
  // A line discount can never exceed the line's gross value — otherwise it
  // would mint a negative taxable value and negative output GST (H2/H6).
  .refine((i) => i.discount === undefined || i.discount <= i.quantity * i.unitPrice, {
    message: 'Line discount cannot exceed quantity × unit price',
    path: ['discount'],
  });

/// Reject an invoice-level discount larger than the whole taxable value
/// (after line discounts) — keeps the document total from going negative
/// (H3). The engine also clamps, but a clear 400 beats a silent clamp.
function refineHeaderDiscount<T extends { discount?: number; items: Array<{ quantity: number; unitPrice: number; discount?: number }> }>(
  data: T,
  ctx: z.RefinementCtx,
): void {
  if (data.discount === undefined) return;
  const baseTaxable = data.items.reduce(
    (s, i) => s + (i.quantity * i.unitPrice - (i.discount ?? 0)),
    0,
  );
  if (data.discount > baseTaxable) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Invoice discount cannot exceed the total taxable value',
      path: ['discount'],
    });
  }
}

const documentTypeEnum = z.enum([
  'TAX_INVOICE',
  'BILL_OF_SUPPLY',
  'ESTIMATE',
  'PROFORMA',
  'CREDIT_NOTE',
  'DEBIT_NOTE',
]);

const createInvoiceSchema = z.object({
  type: z.enum(['SALE', 'PURCHASE']),
  documentType: documentTypeEnum.optional(),
  placeOfSupplyStateCode: z.string().regex(/^\d{2}$/, 'must be 2-digit GST state code').optional(),
  vendorId: z.number().int().positive().optional(),
  partyId: z.number().int().positive().optional(),
  customerName: z.string().max(200).optional(),
  customerPhone: z.string().max(20).optional(),
  customerGstin: z.string().max(20).optional(),
  discount: z.number().nonnegative().optional(),
  note: z.string().max(1000).optional(),
  invoiceDate: z.string().datetime().optional(),
  /// GST-5 — invoice-wide tax convention. Defaults to EXCLUSIVE in the engine
  /// when omitted, preserving existing merchant manual-invoice behaviour; a
  /// per-line `isPriceInclusive` still wins over this default.
  isPriceInclusive: z.boolean().optional(),
  items: z.array(itemSchema).min(1),
  confirm: z.boolean().optional(),
}).superRefine(refineHeaderDiscount);

const updateStatusSchema = z.object({
  status: z.enum(['DRAFT', 'CONFIRMED', 'CANCELLED']),
});

const updateInvoiceSchema = z.object({
  type: z.enum(['SALE', 'PURCHASE']),
  documentType: documentTypeEnum.optional(),
  placeOfSupplyStateCode: z.string().regex(/^\d{2}$/, 'must be 2-digit GST state code').optional(),
  vendorId: z.number().int().positive().nullable().optional(),
  partyId: z.number().int().positive().nullable().optional(),
  customerName: z.string().max(200).optional(),
  customerPhone: z.string().max(20).optional(),
  customerGstin: z.string().max(20).optional(),
  discount: z.number().nonnegative().optional(),
  note: z.string().max(1000).optional(),
  isPriceInclusive: z.boolean().optional(),
  items: z.array(itemSchema).min(1),
}).superRefine(refineHeaderDiscount);

const listQuerySchema = z.object({
  type: z.enum(['SALE', 'PURCHASE']).optional(),
  status: z.enum(['DRAFT', 'CONFIRMED', 'CANCELLED']).optional(),
  documentType: documentTypeEnum.optional(),
  vendorId: z.coerce.number().int().positive().optional(),
  partyId: z.coerce.number().int().positive().optional(),
  productId: z.coerce.number().int().positive().optional(),
  search: z.string().optional(),
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

export class InvoicesController {
  async create(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const payload = createInvoiceSchema.parse(req.body);
    const result = await invoicesService.createInvoice({
      ...payload,
      shopId,
      confirmedById: payload.confirm ? req.user?.sub : undefined,
    });
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    const body: Record<string, unknown> = {
      ...result.invoice,
      confirmed: result.confirmed,
    };
    if ('confirmError' in result && result.confirmError) {
      body.confirmError = result.confirmError;
    }
    res.status(201).json(body);
  }

  async list(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { page, limit, skip } = parsePagination(req);
    const query = listQuerySchema.parse(req.query);

    const { invoices, total } = await invoicesService.listInvoices(shopId, {
      type: query.type,
      status: query.status,
      documentType: query.documentType,
      vendorId: query.vendorId,
      partyId: query.partyId,
      productId: query.productId,
      search: query.search ?? '',
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(invoices, total, { page, limit, skip }));
  }

  async convert(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const result = await invoicesService.convertEstimate(shopId, id);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(201).json(result.invoice);
  }

  async getById(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const invoice = await invoicesService.getInvoiceById(shopId, id);
    if (!invoice) { res.status(404).json({ error: 'Invoice not found' }); return; }

    res.json(invoice);
  }

  async update(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const payload = updateInvoiceSchema.parse(req.body);
    const result = await invoicesService.updateInvoice(shopId, id, payload);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json(result.invoice);
  }

  async updateStatus(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const { status } = updateStatusSchema.parse(req.body);
    const result = await invoicesService.updateStatus(shopId, id, status, req.user?.sub);
    if ('error' in result) {
      res.status(400).json({
        error: result.error,
        ...('productId' in result
          ? { productId: result.productId, available: result.available, requested: result.requested }
          : {}),
      });
      return;
    }
    res.json(result.invoice);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const result = await invoicesService.deleteInvoice(shopId, id);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(204).send();
  }

  async downloadPdf(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    // Look up the invoice once so we can both (a) bail with 404 before
    // streaming headers if it doesn't exist and (b) name the download.
    const invoice = await invoicesService.getInvoiceById(shopId, id);
    if (!invoice) {
      res.status(404).json({ error: 'Invoice not found' });
      return;
    }
    const filename = `invoice-${invoice.invoiceNo ?? id}.pdf`;

    // Stream PDF directly to the response — no full-buffer in memory.
    // streamPdf invokes onReady only AFTER the invoice has been
    // re-verified inside the renderer and right before bytes flow, so
    // a late not-found / state error still gets a clean JSON 5xx
    // because headers haven't been touched yet.
    const err = await invoicesService.streamPdf(shopId, id, res, () => {
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
}

export const invoicesController = new InvoicesController();
