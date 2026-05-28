import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import {
  purchaseRequestsService,
  assertShopOwnership,
  notifyShopOwner,
} from './purchase-requests.service.js';
import { notificationsService } from '../notifications/notifications.service.js';

const createSchema = z.object({
  /// Full cart payload. The server groups by shop and creates one
  /// CustomerOrder parent plus one PurchaseRequest per shop the cart
  /// spans — the FE no longer splits, so a single POST per checkout.
  ///
  /// Each line carries `expectedUnitPrice`: the price the customer was
  /// looking at when they tapped "Place order". The server compares
  /// that against the live `sellingPrice` (or flash price) and aborts
  /// with PRICE_DRIFT if any line moved — protects the buyer from
  /// silent over-charging when a flash sale ends mid-checkout.
  items: z
    .array(
      z.object({
        productId: z.number().int().positive(),
        quantity: z.number().positive(),
        /// Per-line price the client believes is correct. Optional for
        /// backwards compatibility with older builds; once both apps
        /// have shipped a build that always sends it we can make it
        /// required.
        expectedUnitPrice: z.number().nonnegative().optional(),
      }),
    )
    .min(1),
  note: z.string().max(500).optional(),
  /// Optional UserAddress id selected at checkout. When present the
  /// service snapshots that address into `customerAddress`.
  addressId: z.number().int().positive().optional(),
  /// Optional promo code. The server validates + redeems atomically
  /// with the order create.
  couponCode: z.string().max(40).optional(),
  /// Apply wallet balance against the cart total (after coupon).
  useWallet: z.boolean().optional(),
});

const decisionSchema = z.object({ note: z.string().max(500).optional() });

/// Replaces the plain `req.user?.shopId` trust pattern in every
/// merchant endpoint. Combines the JWT extraction with a DB-backed
/// ownership reload so a forged or stale token carrying someone
/// else's shopId can't be acted on. Returns the shopId on success,
/// or null after writing a 403 — callers just `if (shopId == null) return`.
async function requireOwnedShop(
  req: Request,
  res: Response,
): Promise<number | null> {
  const shopId = req.user?.shopId;
  const userId = req.user?.sub;
  if (!shopId || !userId) {
    res.status(403).json({ error: 'This account has no shop linked.' });
    return null;
  }
  const ok = await assertShopOwnership(shopId, userId);
  if (!ok) {
    res.status(403).json({ error: 'Shop access denied.' });
    return null;
  }
  return shopId;
}

/// Merchant-recorded shipping milestone. CONFIRMED is set by the
/// service when an invoice is issued; merchants only push milestones
/// from packing onward.
const shippingEventSchema = z.object({
  type: z.enum(['PACKED', 'SHIPPED', 'OUT_FOR_DELIVERY', 'DELIVERED', 'RETURNED']),
  courier: z.string().max(80).optional(),
  awb: z.string().max(80).optional(),
  eta: z.string().datetime().optional(),
  note: z.string().max(500).optional(),
});

/// Inbox filters. Search and date range come in as query strings; we
/// keep the contract loose (strings) and parse defensively so a stray
/// "abc" in date never blows up the request.
const merchantListSchema = z.object({
  status: z.enum(['PENDING', 'CONFIRMED', 'REJECTED', 'CANCELLED']).optional(),
  search: z.string().max(80).optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

/// Pull the per-request idempotency token off the canonical header. We
/// also tolerate the unprefixed `Idempotency-Key` form (RFC draft name)
/// so curl/Postman testers don't need to remember the X- prefix.
function readIdempotencyKey(req: Request): string | undefined {
  const raw = (req.get('x-idempotency-key') ?? req.get('idempotency-key') ?? '').trim();
  if (!raw) return undefined;
  // Anchor to a reasonable shape — UUID-ish, ≤ 80 chars. Lets us add
  // the unique index without worrying about adversarial payloads.
  if (raw.length > 80) return undefined;
  return raw;
}

/// Map the customer-facing error codes to user-friendly response bodies.
/// Kept controller-side so the service stays domain-clean.
function cancelErrorMessage(code: 'NOT_FOUND' | 'NOT_OWNED' | 'NOT_PENDING'): {
  status: number;
  body: { error: string; code: string };
} {
  switch (code) {
    case 'NOT_FOUND':
      return { status: 404, body: { error: 'Order not found', code } };
    case 'NOT_OWNED':
      return { status: 403, body: { error: 'You can only cancel your own orders', code } };
    case 'NOT_PENDING':
      return {
        status: 409,
        body: {
          error: 'This order can no longer be cancelled — the shop has already acted on it.',
          code,
        },
      };
  }
}

export class PurchaseRequestsController {
  // ── Customer-facing ────────────────────────────────────────────────

  async createForCustomer(req: Request, res: Response): Promise<void> {
    const payload = createSchema.parse(req.body);
    const userId = req.user!.sub;
    const idempotencyKey = readIdempotencyKey(req);

    const result = await purchaseRequestsService.createForCustomer({
      customerUserId: userId,
      items: payload.items,
      note: payload.note,
      idempotencyKey,
      addressId: payload.addressId,
      couponCode: payload.couponCode,
      useWallet: payload.useWallet,
    });
    if ('error' in result) {
      const status =
        result.error === 'ADDRESS_NOT_OWNED' ? 422 :
        result.error === 'OWN_SHOP_ITEM' ? 422 :
        result.error === 'SHOP_NOT_FOUND' ? 404 :
        result.error === 'CROSS_SHOP_ITEM' ? 422 :
        result.error === 'COUPON_INVALID' ? 400 :
        result.error === 'PRICE_DRIFT' ? 409 :
        400;
      res.status(status).json({
        error: result.error,
        // PRICE_DRIFT ships the per-line corrected price so the client
        // can show "Item X is now ₹Y" in the toast without a refetch.
        ...('priceDrift' in result && result.priceDrift
          ? { details: result.priceDrift }
          : {}),
      });
      return;
    }

    // One bell-fan per child shop, never broader. Skip on idempotent
    // replay so a network-retried POST doesn't double-notify.
    if (!result.deduplicated) {
      for (const child of result.order.shopOrders) {
        void notifyShopOwner(child.shopId, {
          kind: 'ORDER_RECEIVED',
          title: 'New order',
          body: `Order #${child.id}`,
          data: { requestId: child.id, customerOrderId: result.order.id },
        }).catch(() => {});
      }
    }

    res.status(result.deduplicated ? 200 : 201).json(result.order);
  }

  async listForCustomer(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const { data, total } = await purchaseRequestsService.listForCustomer({
      userId: req.user!.sub,
      skip,
      limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async getForCustomer(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const request = await purchaseRequestsService.getForCustomer({
      userId: req.user!.sub,
      id,
    });
    if (!request) { res.status(404).json({ error: 'Order not found' }); return; }
    res.json(request);
  }

  /// Customer-side — return cart-ready items from a past order. The
  /// client is expected to feed `items` into the cart provider; the
  /// `skipped` list drives a "3 added · 1 unavailable" toast.
  async reorderForCustomer(req: Request, res: Response): Promise<void> {
    const parentId = parseId(req.params.id);
    if (!parentId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const result = await purchaseRequestsService.reorderItems({
      userId: req.user!.sub,
      parentId,
    });
    if ('error' in result) {
      res.status(404).json({ error: 'Order not found', code: result.error });
      return;
    }
    res.json(result);
  }

  /// Customer-side PDF download — re-uses the merchant invoice
  /// generator after a buyer-ownership check (the parent + child must
  /// belong to the calling user and the child must be CONFIRMED with
  /// a linked invoice).
  async downloadCustomerInvoicePdf(req: Request, res: Response): Promise<void> {
    const parentId = parseId(req.params.id);
    const childId = parseId(req.params.childId);
    if (!parentId || !childId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const ctx = await purchaseRequestsService.customerInvoiceContext({
      userId: req.user!.sub,
      parentId,
      childId,
    });
    if ('error' in ctx) {
      if (ctx.error === 'NOT_FOUND') res.status(404).json({ error: 'Order not found' });
      else res.status(409).json({ error: 'No invoice has been issued for this order yet.' });
      return;
    }
    // Delegate to the invoice service. Dynamic import keeps the
    // top-level dependency graph shallow — this controller doesn't
    // otherwise care about PDF generation. Headers flip to PDF only
    // once the renderer has confirmed the invoice loaded, so a late
    // error still returns a clean JSON response.
    const { invoicesService } = await import('../invoices/invoices.service.js');
    const streamErr = await invoicesService.streamPdf(
      ctx.shopId,
      ctx.invoiceId,
      res,
      () => {
        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader(
          'Content-Disposition',
          `attachment; filename="invoice-${ctx.invoiceNo}.pdf"`,
        );
      },
    );
    if (streamErr) {
      if (!res.headersSent) {
        res.status(404).json({ error: streamErr.error });
      } else {
        res.end();
      }
    }
  }

  async cancelChildForCustomer(req: Request, res: Response): Promise<void> {
    const parentId = parseId(req.params.id);
    const childId = parseId(req.params.childId);
    if (!parentId || !childId) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const result = await purchaseRequestsService.cancelChildForCustomer({
      userId: req.user!.sub,
      parentId,
      childId,
    });
    if ('error' in result) {
      const { status, body } = cancelErrorMessage(result.error);
      res.status(status).json(body);
      return;
    }
    res.status(204).send();
  }

  // ── Merchant-facing ────────────────────────────────────────────────

  async listForMerchant(req: Request, res: Response): Promise<void> {
    const shopId = await requireOwnedShop(req, res);
    if (shopId == null) return;
    const { page, limit, skip } = parsePagination(req);
    const filters = merchantListSchema.parse({
      status: req.query.status,
      search: req.query.search,
      from: req.query.from,
      to: req.query.to,
    });
    const { data, total } = await purchaseRequestsService.listForMerchant({
      ...filters,
      shopId,
      from: filters.from ? new Date(filters.from) : undefined,
      to: filters.to ? new Date(filters.to) : undefined,
      skip,
      limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async pendingCount(req: Request, res: Response): Promise<void> {
    const shopId = await requireOwnedShop(req, res);
    if (shopId == null) return;
    const count = await purchaseRequestsService.pendingCount(shopId);
    res.json({ count });
  }

  async getForMerchant(req: Request, res: Response): Promise<void> {
    const shopId = await requireOwnedShop(req, res);
    if (shopId == null) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const request = await purchaseRequestsService.getForMerchant(shopId, id);
    if (!request) { res.status(404).json({ error: 'Order not found' }); return; }
    res.json(request);
  }

  async confirm(req: Request, res: Response): Promise<void> {
    const shopId = await requireOwnedShop(req, res);
    if (shopId == null) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = decisionSchema.parse(req.body ?? {});

    const result = await purchaseRequestsService.confirmRequest({
      shopId,
      requestId: id,
      decidedById: req.user!.sub,
      note: payload.note,
    });
    if ('error' in result) {
      const status =
        result.error === 'NOT_FOUND'
          ? 404
          : result.error === 'INSUFFICIENT_STOCK'
            ? 409
            : 409;
      res.status(status).json(result);
      return;
    }

    const request = await purchaseRequestsService.getForMerchant(shopId, id);
    if (request) {
      void notificationsService
        .create({
          userId: request.customerUserId,
          kind: 'ORDER_CONFIRMED',
          title: 'Order confirmed',
          body: `Invoice ${result.invoice.invoiceNo} has been created`,
          data: { requestId: id, invoiceId: result.invoice.id },
        })
        .catch(() => {});
    }
    res.json(result);
  }

  async reject(req: Request, res: Response): Promise<void> {
    const shopId = await requireOwnedShop(req, res);
    if (shopId == null) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = decisionSchema.parse(req.body ?? {});

    const result = await purchaseRequestsService.rejectRequest({
      shopId,
      requestId: id,
      decidedById: req.user!.sub,
      note: payload.note,
    });
    if ('error' in result) {
      res.status(result.error === 'NOT_FOUND' ? 404 : 409).json({ error: result.error });
      return;
    }

    const request = await purchaseRequestsService.getForMerchant(shopId, id);
    if (request) {
      void notificationsService
        .create({
          userId: request.customerUserId,
          kind: 'ORDER_REJECTED',
          title: 'Order declined',
          body: payload.note ?? 'The merchant declined this order.',
          data: { requestId: id },
        })
        .catch(() => {});
    }
    res.status(204).send();
  }

  /// Merchant-side — record a shipping milestone (PACKED, SHIPPED,
  /// OUT_FOR_DELIVERY, DELIVERED, RETURNED). Drives the customer-facing
  /// tracking timeline.
  async addShippingEvent(req: Request, res: Response): Promise<void> {
    const shopId = await requireOwnedShop(req, res);
    if (shopId == null) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = shippingEventSchema.parse(req.body ?? {});
    const result = await purchaseRequestsService.addShippingEvent({
      shopId,
      requestId: id,
      actorId: req.user!.sub,
      type: payload.type,
      courier: payload.courier ?? null,
      awb: payload.awb ?? null,
      eta: payload.eta ? new Date(payload.eta) : null,
      note: payload.note ?? null,
    });
    if ('error' in result) {
      if (result.error === 'NOT_FOUND') res.status(404).json({ error: 'Order not found' });
      else res.status(409).json({ error: 'Order must be confirmed before shipping events can be recorded.' });
      return;
    }
    // Notify the buyer with a short status line so the bell badge
    // updates without polling. Body uses a friendly label per type.
    const labels: Record<string, string> = {
      PACKED: 'Your order has been packed.',
      SHIPPED: 'Your order is on the way.',
      OUT_FOR_DELIVERY: 'Out for delivery today.',
      DELIVERED: 'Your order was delivered.',
      RETURNED: 'Your order was marked as returned.',
    };
    const request = await purchaseRequestsService.getForMerchant(shopId, id);
    if (request) {
      void notificationsService
        .create({
          userId: request.customerUserId,
          kind: 'ORDER_UPDATE',
          title: 'Order update',
          body: labels[payload.type] ?? `Status: ${payload.type}`,
          data: { requestId: id, type: payload.type },
        })
        .catch(() => {});
    }
    res.status(201).json(result);
  }
}

export const purchaseRequestsController = new PurchaseRequestsController();
