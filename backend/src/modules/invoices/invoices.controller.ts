import { Request, Response } from 'express';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { decodeId } from '../../shared/ids/publicId.js';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { invoicesService } from './invoices.service.js';
import { isValidStateCode, PINCODE_REGEX } from '../../shared/validation/indian.js';

const GST_SLABS = new Set([0, 0.1, 0.25, 1, 1.5, 3, 5, 12, 18, 28]);

const itemSchema = z
  .object({
    productId: zPublicId,
    quantity: z.number().positive(),
    unitPrice: z.number().nonnegative(),
    taxPercent: z
      .number()
      .min(0)
      .max(100)
      .refine((r) => GST_SLABS.has(r), {
        message: 'taxPercent must be a valid GST slab (0, 0.1, 0.25, 1, 1.5, 3, 5, 12, 18, 28)',
      })
      .optional(),
    cessRate: z.number().min(0).max(100).optional(),
    discount: z.number().nonnegative().optional(),
    isPriceInclusive: z.boolean().optional(),
  })
  .refine((i) => i.discount === undefined || i.discount <= i.quantity * i.unitPrice, {
    message: 'Line discount cannot exceed quantity × unit price',
    path: ['discount'],
  });

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

const creatableDocumentTypeEnum = z.enum([
  'TAX_INVOICE',
  'BILL_OF_SUPPLY',
  'ESTIMATE',
  'PROFORMA',
]);

const noteLineSchema = z.object({
  productId: zPublicId,
  quantity: z.number().positive(),
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

const recipientAddressFields = {
  customerAddress: z.string().max(500).optional(),
  customerCity: z.string().max(120).optional(),
  customerState: z.string().max(120).optional(),
  customerStateCode: z
    .string()
    .regex(/^\d{2}$/, 'must be 2-digit GST state code')
    .optional(),
  customerPinCode: z
    .string()
    .regex(PINCODE_REGEX, 'invalid Indian PIN code')
    .optional(),
} as const;

const createInvoiceSchema = z.object({
  type: z.enum(['SALE', 'PURCHASE']),
  documentType: creatableDocumentTypeEnum.optional(),
  placeOfSupplyStateCode: z.string().regex(/^\d{2}$/, 'must be 2-digit GST state code').optional(),
  vendorId: zPublicId.optional(),
  partyId: zPublicId.optional(),
  customerName: z.string().max(200).optional(),
  customerPhone: z.string().max(20).optional(),
  customerGstin: z.string().max(20).optional(),
  ...recipientAddressFields,
  acknowledgeMissingRecipientDetails: z.boolean().optional(),
  discount: z.number().nonnegative().optional(),
  note: z.string().max(1000).optional(),
  invoiceDate: z.string().datetime().optional(),
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
  ...recipientAddressFields,
  acknowledgeMissingRecipientDetails: z.boolean().optional(),
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
  archived: z.coerce.boolean().optional(),
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
      archived: query.archived,
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

    const result = await invoicesService.setArchived(shopId, id, archived);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.json(result.invoice);
  }

  async downloadPdf(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const invoice = await invoicesService.getInvoiceById(shopId, id);
    if (!invoice) {
      res.status(404).json({ error: 'Invoice not found' });
      return;
    }
    const filename = `invoice-${invoice.invoiceNo ?? id}.pdf`;

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
