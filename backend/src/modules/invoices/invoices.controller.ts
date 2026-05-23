import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { invoicesService } from './invoices.service.js';

const itemSchema = z.object({
  productId: z.number().int().positive(),
  quantity: z.number().positive(),
  unitPrice: z.number().nonnegative(),
  taxPercent: z.number().min(0).max(100).optional(),
  /// GST compensation cess. Most line items leave this at 0; tobacco /
  /// luxury goods / aerated drinks attract it.
  cessRate: z.number().min(0).max(100).optional(),
  discount: z.number().nonnegative().optional(),
});

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
  /// Defaults server-side to TAX_INVOICE when omitted.
  documentType: documentTypeEnum.optional(),
  /// 2-digit GST state code of the place of supply. When omitted the
  /// service derives it (customer state for SALE, shop state for PURCHASE).
  placeOfSupplyStateCode: z.string().regex(/^\d{2}$/, 'must be 2-digit GST state code').optional(),
  vendorId: z.number().int().positive().optional(),
  partyId: z.number().int().positive().optional(),
  customerName: z.string().max(200).optional(),
  customerPhone: z.string().max(20).optional(),
  customerGstin: z.string().max(20).optional(),
  discount: z.number().nonnegative().optional(),
  note: z.string().max(1000).optional(),
  invoiceDate: z.string().datetime().optional(),
  items: z.array(itemSchema).min(1),
});

const updateStatusSchema = z.object({
  status: z.enum(['DRAFT', 'CONFIRMED', 'CANCELLED']),
});

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

export class InvoicesController {
  async create(req: Request, res: Response): Promise<void> {
    const payload = createInvoiceSchema.parse(req.body);
    const result = await invoicesService.createInvoice(payload);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(201).json(result.invoice);
  }

  async list(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const query = listQuerySchema.parse(req.query);

    const { invoices, total } = await invoicesService.listInvoices({
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
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const result = await invoicesService.convertEstimate(id);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(201).json(result.invoice);
  }

  async getById(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const invoice = await invoicesService.getInvoiceById(id);
    if (!invoice) { res.status(404).json({ error: 'Invoice not found' }); return; }

    res.json(invoice);
  }

  async updateStatus(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const { status } = updateStatusSchema.parse(req.body);
    const result = await invoicesService.updateStatus(id, status, req.user?.sub);
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
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const result = await invoicesService.deleteInvoice(id);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }
    res.status(204).send();
  }

  async downloadPdf(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const result = await invoicesService.generatePdf(id);
    if (!Buffer.isBuffer(result)) {
      res.status(404).json({ error: result.error });
      return;
    }

    const invoice = await invoicesService.getInvoiceById(id);
    const filename = `invoice-${invoice?.invoiceNo ?? id}.pdf`;

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Length', result.length);
    res.send(result);
  }
}

export const invoicesController = new InvoicesController();
