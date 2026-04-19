import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { invoicesService } from './invoices.service.js';

const itemSchema = z.object({
  productId: z.number().int().positive(),
  quantity: z.number().positive(),
  unitPrice: z.number().nonnegative(),
  taxPercent: z.number().min(0).max(100).optional(),
  discount: z.number().nonnegative().optional(),
});

const createInvoiceSchema = z.object({
  type: z.enum(['SALE', 'PURCHASE']),
  vendorId: z.number().int().positive().optional(),
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
    const type = req.query.type as string | undefined;
    const status = req.query.status as string | undefined;
    const vendorId = req.query.vendorId ? Number(req.query.vendorId) : undefined;
    const search = (req.query.search as string) || '';

    const { invoices, total } = await invoicesService.listInvoices({
      type,
      status,
      vendorId,
      search,
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(invoices, total, { page, limit, skip }));
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
    const result = await invoicesService.updateStatus(id, status);
    if ('error' in result) {
      res.status(400).json({ error: result.error });
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
