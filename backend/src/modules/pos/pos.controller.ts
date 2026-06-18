import { Request, Response } from 'express';
import { z } from 'zod';
import { posService } from './pos.service.js';
import { hasRight, manageRight } from '../../shared/http/permissions.js';
import { issueScanTicket } from '../scan-console/scan-console.service.js';

const qty = z.number().positive().max(100000);

const openSaleSchema = z.object({
  partyId: z.number().int().positive().optional(),
  customerName: z.string().trim().max(120).optional(),
  customerPhone: z.string().trim().max(20).optional(),
});

const opId = z.string().trim().min(1).max(64).optional();
const scanSchema = z.object({ code: z.string().trim().min(1).max(128), opId });

const quickAddSchema = z.object({
  code: z.string().trim().min(1).max(128),
  name: z.string().trim().min(1).max(200),
  sellingPrice: z.number().positive().max(10_000_000),
  taxPercent: z.number().min(0).max(28).optional(),
  openingStock: z.number().positive().max(1_000_000).optional(),
});

const addItemSchema = z.object({
  productId: z.number().int().positive(),
  quantity: qty.default(1),
  opId,
});

const patchItemSchema = z
  .object({
    quantity: z.number().min(0).max(100000).optional(),
    lineDiscount: z.number().min(0).optional(),
    unitPrice: z.number().min(0).optional(),
  })
  .refine((v) => v.quantity != null || v.lineDiscount != null || v.unitPrice != null, {
    message: 'Provide at least one of quantity, lineDiscount, unitPrice',
  });

const patchSaleSchema = z.object({
  headerDiscount: z.number().min(0).optional(),
});

// POS tender modes mirror the Payment.mode enum minus CAUTION (system-only).
const TENDER_MODES = ['CASH', 'UPI', 'CARD', 'NEFT', 'RTGS', 'CHEQUE', 'OTHER'] as const;
const checkoutSchema = z.object({
  tender: z.object({
    mode: z.enum(TENDER_MODES),
    modeReference: z.string().trim().max(120).optional(),
  }),
  customer: z
    .object({ name: z.string().trim().max(120).optional(), phone: z.string().trim().max(20).optional() })
    .optional(),
});

const saleId = (req: Request) => Number(req.params.id);
const productId = (req: Request) => Number(req.params.productId);

/// Returns the snapshot (or 4xx with the error). Most cart mutations resolve to
/// a fresh snapshot, so they share this terminator.
function sendSnapshot(res: Response, result: { error: string } | unknown, okStatus = 200) {
  if (result && typeof result === 'object' && 'error' in (result as Record<string, unknown>)) {
    res.status(400).json(result);
    return;
  }
  res.status(okStatus).json(result);
}

class PosController {
  /// Mint a WebSocket ticket for the live cart from the POS (invoices) area, so
  /// a cashier with invoices perms but not products:manage can still connect —
  /// the scan-console ticket endpoint sits under the products area (review H3).
  async ticket(req: Request, res: Response): Promise<void> {
    const ticket = issueScanTicket(req.shopId!, req.user!.sub, Date.now());
    res.json({ ticket, path: '/ws/scan-console', expiresInMs: 30_000 });
  }

  async openSale(req: Request, res: Response): Promise<void> {
    const parsed = openSaleSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid sale', issues: parsed.error.issues });
      return;
    }
    sendSnapshot(res, await posService.openSale(req.shopId!, req.user!.sub, parsed.data), 201);
  }

  async listOpenSales(req: Request, res: Response): Promise<void> {
    res.json(await posService.listOpenSales(req.shopId!));
  }

  async getSale(req: Request, res: Response): Promise<void> {
    const result = await posService.snapshot(req.shopId!, saleId(req));
    if ('error' in result) {
      res.status(404).json(result);
      return;
    }
    res.json(result);
  }

  async scan(req: Request, res: Response): Promise<void> {
    const parsed = scanSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'A scanned "code" is required' });
      return;
    }
    const result = await posService.addScan(req.shopId!, saleId(req), parsed.data.code, req.user!.sub, parsed.data.opId);
    // Unknown code → 200 with { unknown } so the till can offer Quick add.
    sendSnapshot(res, result);
  }

  async addItem(req: Request, res: Response): Promise<void> {
    const parsed = addItemSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid item', issues: parsed.error.issues });
      return;
    }
    sendSnapshot(
      res,
      await posService.addProduct(req.shopId!, saleId(req), parsed.data.productId, parsed.data.quantity, req.user!.sub, parsed.data.opId),
    );
  }

  async patchItem(req: Request, res: Response): Promise<void> {
    const parsed = patchItemSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid update', issues: parsed.error.issues });
      return;
    }
    const sId = saleId(req);
    const pId = productId(req);
    const { quantity, lineDiscount, unitPrice } = parsed.data;
    // Apply in a stable order; each returns a snapshot, last one wins as response.
    let result: Awaited<ReturnType<typeof posService.setQty>> | undefined;
    if (unitPrice != null) result = await posService.setUnitPrice(req.shopId!, sId, pId, unitPrice);
    if (lineDiscount != null) result = await posService.setLineDiscount(req.shopId!, sId, pId, lineDiscount);
    if (quantity != null) result = await posService.setQty(req.shopId!, sId, pId, quantity);
    sendSnapshot(res, result!);
  }

  async removeItem(req: Request, res: Response): Promise<void> {
    sendSnapshot(res, await posService.removeLine(req.shopId!, saleId(req), productId(req)));
  }

  /// Quick-add a brand-new product from an unknown scan, then add it to the cart.
  /// Creating catalogue requires products:manage (beyond the POS area's
  /// invoices:manage), so a cashier can bill but not silently mint products.
  async quickAdd(req: Request, res: Response): Promise<void> {
    if (!hasRight(req.user!.shopRole, req.user!.shopPermissions, manageRight('products'))) {
      res.status(403).json({ error: 'You need product management access to add new products' });
      return;
    }
    const parsed = quickAddSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid product', issues: parsed.error.issues });
      return;
    }
    sendSnapshot(res, await posService.quickAddProduct(req.shopId!, saleId(req), parsed.data, req.user!.sub), 201);
  }

  async patchSale(req: Request, res: Response): Promise<void> {
    const parsed = patchSaleSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid update', issues: parsed.error.issues });
      return;
    }
    if (parsed.data.headerDiscount == null) {
      sendSnapshot(res, await posService.snapshot(req.shopId!, saleId(req)));
      return;
    }
    sendSnapshot(res, await posService.setHeaderDiscount(req.shopId!, saleId(req), parsed.data.headerDiscount));
  }

  async voidSale(req: Request, res: Response): Promise<void> {
    const result = await posService.voidSale(req.shopId!, saleId(req));
    if ('error' in result) {
      res.status(400).json(result);
      return;
    }
    res.json(result);
  }

  async checkout(req: Request, res: Response): Promise<void> {
    const parsed = checkoutSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid checkout', issues: parsed.error.issues });
      return;
    }
    const result = await posService.checkout(req.shopId!, saleId(req), parsed.data, req.user!.sub);
    if ('error' in result) {
      res.status(409).json(result);
      return;
    }
    res.json(result);
  }
}

export const posController = new PosController();
