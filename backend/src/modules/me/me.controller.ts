import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { meService } from './me.service.js';
import { quotationsService, QuotationStatus } from '../quotations/quotations.service.js';

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

const quotationStatusSchema = z
  .enum(['REQUESTED', 'PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED'])
  .optional();

const declineQuotationSchema = z.object({
  declineNote: z.string().max(500).nullable().optional(),
});

/// One line in a customer-built quote request (advisory catalogue prices; the
/// merchant re-prices before sending the quotation back).
const quoteRequestItemSchema = z.object({
  productId: z.number().int().positive(),
  name: z.string().max(200),
  sku: z.string().max(120).nullable().optional(),
  quantity: z.number().positive(),
  unitPrice: z.number().nonnegative(),
  taxPercent: z.number().min(0).max(100).nullable().optional(),
  imageUrl: z.string().max(2000).nullable().optional(),
});

const requestQuotationSchema = z.object({
  items: z.array(quoteRequestItemSchema).min(1).max(100),
  note: z.string().max(500).nullable().optional(),
});

export class MeController {
  async catalog(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const search = (req.query.search as string) || '';
    const categoryRaw = req.query.categoryId as string | undefined;
    const categoryId = categoryRaw ? parseId(categoryRaw) ?? undefined : undefined;

    const { data, total } = await meService.listCatalog({
      search,
      categoryId,
      skip,
      limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async catalogProduct(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.productId);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const product = await meService.getCatalogProduct(id);
    if (!product) { res.status(404).json({ error: 'Product not found' }); return; }
    res.json(product);
  }

  async catalogCategories(_req: Request, res: Response): Promise<void> {
    const data = await meService.listCategoriesWithCounts();
    res.json(data);
  }

  async links(req: Request, res: Response): Promise<void> {
    const data = await meService.links(req.user!.sub);
    res.json(data);
  }

  async linkedShops(req: Request, res: Response): Promise<void> {
    const data = await meService.linkedShops(req.user!.sub);
    res.json({ data });
  }

  async partyInvoices(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    if (!partyId) { res.status(400).json({ error: 'Invalid party id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const { page, limit, skip } = parsePagination(req);
    const { data, total } = await meService.listInvoicesForParty({
      partyId,
      skip,
      limit,
    });
    const body = paginatedResponse(data, total, { page, limit, skip });
    res.json({ ...body, party });
  }

  async vendorInvoices(req: Request, res: Response): Promise<void> {
    const vendorId = parseId(req.params.vendorId);
    if (!vendorId) { res.status(400).json({ error: 'Invalid vendor id' }); return; }
    const vendor = await meService.assertOwnsVendor(req.user!.sub, vendorId);
    if (!vendor) { res.status(403).json({ error: 'Not linked to this vendor' }); return; }

    const { page, limit, skip } = parsePagination(req);
    const { data, total } = await meService.listInvoicesForVendor({
      vendorId,
      skip,
      limit,
    });
    const body = paginatedResponse(data, total, { page, limit, skip });
    res.json({ ...body, vendor });
  }

  /// Quotations the merchant sent to a party the caller is linked to. Listing
  /// + detail are reads; accept/decline are writes (gated by assertOwnsParty).
  async quotations(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    if (!partyId) { res.status(400).json({ error: 'Invalid party id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const { page, limit, skip } = parsePagination(req);
    const status = quotationStatusSchema.parse(req.query.status) as
      | QuotationStatus
      | undefined;
    const { data, total } = await quotationsService.listForParty(
      party.shop.id,
      partyId,
      { status, skip, take: limit },
    );
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async quotation(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    const quotationId = parseId(req.params.quotationId);
    if (!partyId || !quotationId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const quotation = await quotationsService.getForParty(party.shop.id, partyId, quotationId);
    if (!quotation) { res.status(404).json({ error: 'Quotation not found' }); return; }
    res.json(quotation);
  }

  async acceptQuotation(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    const quotationId = parseId(req.params.quotationId);
    if (!partyId || !quotationId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const result = await quotationsService.accept(
      party.shop.id,
      partyId,
      quotationId,
      req.user!.sub,
    );
    res.json(result);
  }

  async declineQuotation(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    const quotationId = parseId(req.params.quotationId);
    if (!partyId || !quotationId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const { declineNote } = declineQuotationSchema.parse(req.body ?? {});
    const result = await quotationsService.decline(
      party.shop.id,
      partyId,
      quotationId,
      declineNote,
    );
    res.json(result);
  }

  /// Customer builds a basket and asks the shop for a quote (status REQUESTED).
  async requestQuotation(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    if (!partyId) { res.status(400).json({ error: 'Invalid party id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const payload = requestQuotationSchema.parse(req.body);
    const result = await quotationsService.requestByCustomer(
      party.shop.id,
      partyId,
      req.user!.sub,
      { items: payload.items, note: payload.note },
    );
    if ('error' in result) {
      if (result.error === 'NO_VALID_ITEMS') {
        res
          .status(400)
          .json({ error: 'None of the requested items are available in this shop' });
        return;
      }
      res.status(404).json({ error: 'Shop not found' });
      return;
    }
    res.status(201).json(result.quotation);
  }

  /// Customer downloads a quotation (the shop sent, or they requested) as PDF.
  async quotationPdf(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    const quotationId = parseId(req.params.quotationId);
    if (!partyId || !quotationId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const quotation = await quotationsService.getForParty(party.shop.id, partyId, quotationId);
    if (!quotation) { res.status(404).json({ error: 'Quotation not found' }); return; }
    const filename = `quotation-${quotation.quotationNo ?? quotationId}.pdf`;
    const err = await quotationsService.streamPdf(party.shop.id, quotationId, res, () => {
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    });
    if (err) {
      if (!res.headersSent) res.status(500).json({ error: err.error });
      else res.end();
    }
  }

  /// Customer withdraws their own REQUESTED quote.
  async cancelQuotation(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    const quotationId = parseId(req.params.quotationId);
    if (!partyId || !quotationId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const result = await quotationsService.cancelRequest(
      party.shop.id,
      partyId,
      quotationId,
    );
    res.json(result);
  }

  async partyInvoice(req: Request, res: Response): Promise<void> {
    const partyId = parseId(req.params.partyId);
    const invoiceId = parseId(req.params.invoiceId);
    if (!partyId || !invoiceId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const party = await meService.assertOwnsParty(req.user!.sub, partyId);
    if (!party) { res.status(403).json({ error: 'Not linked to this party' }); return; }

    const invoice = await meService.getInvoiceForParty({ partyId, invoiceId });
    if (!invoice) { res.status(404).json({ error: 'Invoice not found' }); return; }
    res.json(invoice);
  }

  async wishlist(req: Request, res: Response): Promise<void> {
    const data = await meService.listWishlist(req.user!.sub);
    res.json({ data });
  }

  async wishlistAdd(req: Request, res: Response): Promise<void> {
    const productId = parseId(req.params.productId);
    if (!productId) { res.status(400).json({ error: 'Invalid product id' }); return; }
    const result = await meService.addToWishlist(req.user!.sub, productId);
    if ('error' in result) {
      res.status(404).json({ error: result.error });
      return;
    }
    res.status(204).send();
  }

  async wishlistRemove(req: Request, res: Response): Promise<void> {
    const productId = parseId(req.params.productId);
    if (!productId) { res.status(400).json({ error: 'Invalid product id' }); return; }
    await meService.removeFromWishlist(req.user!.sub, productId);
    res.status(204).send();
  }

  async vendorInvoice(req: Request, res: Response): Promise<void> {
    const vendorId = parseId(req.params.vendorId);
    const invoiceId = parseId(req.params.invoiceId);
    if (!vendorId || !invoiceId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const vendor = await meService.assertOwnsVendor(req.user!.sub, vendorId);
    if (!vendor) { res.status(403).json({ error: 'Not linked to this vendor' }); return; }

    const invoice = await meService.getInvoiceForVendor({ vendorId, invoiceId });
    if (!invoice) { res.status(404).json({ error: 'Invoice not found' }); return; }
    res.json(invoice);
  }
}

export const meController = new MeController();
