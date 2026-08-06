import { Request, Response } from 'express';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { decodeId } from '../../shared/ids/publicId.js';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { invoicesService } from './invoices.service.js';
import { isValidStateCode } from '../../shared/validation/indian.js';

/// GST-10 — the legal GST rate slabs an output tax invoice may carry. A client
/// may legitimately override the product's configured rate to mark a line
/// exempt/nil-rated, but it can only ever be one of the notified slabs — never
/// an arbitrary percentage (e.g. 7% on an 18% HSN, which would short-collect
/// output GST). 0 covers exempt/nil; 0.1/0.25/1/1.5/3 are the special-rate
/// slabs (rough diamonds, precious stones, gold, etc.); 5/12/18/28 are the
/// standard slabs. Cess is open-ended (ad-valorem rates vary by HSN) so it is
/// NOT slab-checked.
const GST_SLABS = new Set([0, 0.1, 0.25, 1, 1.5, 3, 5, 12, 18, 28]);

const itemSchema = z
  .object({
    productId: zPublicId,
    quantity: z.number().positive(),
    unitPrice: z.number().nonnegative(),
    /// GST-10 — when supplied, must be one of the notified GST slabs. Omitting
    /// it inherits the product/variant statutory rate (the C1 fallback).
    taxPercent: z
      .number()
      .min(0)
      .max(100)
      .refine((r) => GST_SLABS.has(r), {
        message: 'taxPercent must be a valid GST slab (0, 0.1, 0.25, 1, 1.5, 3, 5, 12, 18, 28)',
      })
      .optional(),
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

/// GST-11 — place-of-supply integrity. The `\d{2}` regex only proves the field
/// is two digits; it does not prove it is a REAL GST state code, nor that it
/// agrees with a B2B recipient's GSTIN. Both matter for IGST-vs-CGST/SGST:
///   1. An unknown code (e.g. "99") would silently be treated as interstate.
///   2. A registered recipient's place of supply is its GSTIN state — if the
///      explicit POS disagrees with the GSTIN's first two digits, the tax head
///      is wrong (CGST/SGST charged where IGST is due, or vice versa).
/// We reject an out-of-table code outright, and reject a POS that contradicts
/// the recipient GSTIN. (When POS is omitted the engine derives it from the
/// customer/shop state, so the GSTIN-based default still applies downstream.)
function refinePlaceOfSupply<
  T extends { placeOfSupplyStateCode?: string; customerGstin?: string },
>(data: T, ctx: z.RefinementCtx): void {
  const pos = data.placeOfSupplyStateCode;
  if (pos !== undefined && !isValidStateCode(pos)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'placeOfSupplyStateCode is not a valid GST state code',
      path: ['placeOfSupplyStateCode'],
    });
    return;
  }
  const gstin = data.customerGstin?.trim().toUpperCase();
  if (pos !== undefined && gstin && gstin.length >= 2) {
    const gstinState = gstin.slice(0, 2);
    // Only cross-check when the GSTIN's state prefix is itself a real code —
    // a malformed GSTIN is rejected separately in the service (GST-6).
    if (isValidStateCode(gstinState) && gstinState !== pos) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message:
          'placeOfSupplyStateCode does not match the recipient GSTIN state',
        path: ['placeOfSupplyStateCode'],
      });
    }
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

/// Document types a client may create directly via POST/PUT /invoices.
/// CREDIT_NOTE / DEBIT_NOTE are DELIBERATELY excluded: a note is a Sec 34
/// adjustment that must reference an original invoice and reverse/add its GST
/// (and, for credit notes, restock) — it can only be raised through
/// POST /invoices/:id/notes, never minted as a bare document here. The full
/// `documentTypeEnum` is still used for the list filter (you can filter by
/// notes) — only creation is restricted.
const creatableDocumentTypeEnum = z.enum([
  'TAX_INVOICE',
  'BILL_OF_SUPPLY',
  'ESTIMATE',
  'PROFORMA',
]);

/// Line of a manually-issued credit/debit note (POST /invoices/:id/notes).
const noteLineSchema = z.object({
  productId: zPublicId,
  quantity: z.number().positive(),
  /// Ignored for CREDIT_NOTE (reverses the original's unit price); required for
  /// DEBIT_NOTE as the supplementary amount charged per unit.
  unitPrice: z.number().nonnegative().optional(),
});

const issueNoteSchema = z
  .object({
    documentType: z.enum(['CREDIT_NOTE', 'DEBIT_NOTE']),
    reason: z.string().max(1000).optional(),
    restock: z.boolean().optional(),
    lines: z.array(noteLineSchema).min(1),
  })
  .superRefine((data, ctx) => {
    // A debit note bills a supplementary amount, so every line needs a
    // positive unitPrice. Credit-note lines reverse the original price and
    // ignore unitPrice entirely.
    if (data.documentType === 'DEBIT_NOTE') {
      data.lines.forEach((line, i) => {
        if (!(line.unitPrice && line.unitPrice > 0)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['lines', i, 'unitPrice'],
            message: 'Debit note lines require a positive unitPrice',
          });
        }
      });
    }
  });

const createInvoiceSchema = z.object({
  type: z.enum(['SALE', 'PURCHASE']),
  documentType: creatableDocumentTypeEnum.optional(),
  placeOfSupplyStateCode: z.string().regex(/^\d{2}$/, 'must be 2-digit GST state code').optional(),
  vendorId: zPublicId.optional(),
  partyId: zPublicId.optional(),
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
})
  .superRefine(refineHeaderDiscount)
  .superRefine(refinePlaceOfSupply);

const updateStatusSchema = z.object({
  status: z.enum(['DRAFT', 'CONFIRMED', 'CANCELLED']),
});

const updateInvoiceSchema = z.object({
  type: z.enum(['SALE', 'PURCHASE']),
  documentType: creatableDocumentTypeEnum.optional(),
  placeOfSupplyStateCode: z.string().regex(/^\d{2}$/, 'must be 2-digit GST state code').optional(),
  vendorId: zPublicId.nullable().optional(),
  partyId: zPublicId.nullable().optional(),
  customerName: z.string().max(200).optional(),
  customerPhone: z.string().max(20).optional(),
  customerGstin: z.string().max(20).optional(),
  discount: z.number().nonnegative().optional(),
  note: z.string().max(1000).optional(),
  isPriceInclusive: z.boolean().optional(),
  items: z.array(itemSchema).min(1),
})
  .superRefine(refineHeaderDiscount)
  .superRefine(refinePlaceOfSupply);

const listQuerySchema = z.object({
  type: z.enum(['SALE', 'PURCHASE']).optional(),
  status: z.enum(['DRAFT', 'CONFIRMED', 'CANCELLED']).optional(),
  documentType: documentTypeEnum.optional(),
  vendorId: zPublicId.optional(),
  partyId: zPublicId.optional(),
  productId: zPublicId.optional(),
  search: z.string().optional(),
  dateFrom: z.string().datetime().optional(),
  dateTo: z.string().datetime().optional(),
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
      dateFrom: query.dateFrom,
      dateTo: query.dateTo,
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

  /// POST /invoices/:id/notes — raise a credit or debit note against a
  /// CONFIRMED sale invoice. The Sec 34 adjustment path (distinct from the
  /// POS/order refund path, which also settles money).
  async issueNote(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const payload = issueNoteSchema.parse(req.body);
    const result = await invoicesService.createAdjustmentNoteFromInvoice(
      shopId,
      id,
      payload,
      req.user?.sub,
    );
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
