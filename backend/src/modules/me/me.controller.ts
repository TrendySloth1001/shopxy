import { Request, Response } from 'express';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { meService } from './me.service.js';

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

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
