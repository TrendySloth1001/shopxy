import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { purchaseRequestsService } from './purchase-requests.service.js';
import { notificationsService } from '../notifications/notifications.service.js';
import prisma from '../../infra/db/prisma.js';

const createSchema = z.object({
  /// Owning merchant — required. The customer-side splits its cart
  /// by shop and fires one POST per shop with that shop's items.
  shopId: z.number().int().positive(),
  items: z
    .array(
      z.object({
        productId: z.number().int().positive(),
        quantity: z.number().positive(),
      }),
    )
    .min(1),
  note: z.string().max(500).optional(),
  /// Optional UserAddress id selected at checkout. When present the
  /// service snapshots that address into `customerAddress`.
  addressId: z.number().int().positive().optional(),
});

const decisionSchema = z.object({ note: z.string().max(500).optional() });

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
      shopId: payload.shopId,
      customerUserId: userId,
      items: payload.items,
      note: payload.note,
      idempotencyKey,
      addressId: payload.addressId,
    });
    if ('error' in result) {
      const status =
        result.error === 'ADDRESS_NOT_OWNED' ? 422 :
        result.error === 'OWN_SHOP_ITEM' ? 422 :
        result.error === 'SHOP_NOT_FOUND' ? 404 :
        result.error === 'CROSS_SHOP_ITEM' ? 422 :
        400;
      res.status(status).json({ error: result.error });
      return;
    }

    // Notify *only the receiving shop's owner* — not the historical
    // fan-out to every OWNER row in the DB, which leaked one merchant's
    // orders to every other merchant's notification bell.
    if (!result.deduplicated) {
      void notifyShopOwner(payload.shopId, {
        kind: 'ORDER_RECEIVED',
        title: 'New order',
        body: `Order #${result.request.id}`,
        data: { requestId: result.request.id },
      }).catch(() => {});
    }

    res.status(result.deduplicated ? 200 : 201).json(result.request);
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

  async cancelForCustomer(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const result = await purchaseRequestsService.cancelForCustomer({
      userId: req.user!.sub,
      id,
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
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
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
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const count = await purchaseRequestsService.pendingCount(shopId);
    res.json({ count });
  }

  async getForMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const request = await purchaseRequestsService.getForMerchant(shopId, id);
    if (!request) { res.status(404).json({ error: 'Order not found' }); return; }
    res.json(request);
  }

  async confirm(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
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
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
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
}

/// Fans out an in-app notification to every merchant (anyone with role
/// OWNER). One Promise.all on the User read + creates so a 50-merchant
/// fleet doesn't pay sequential latency for the notification storm.
async function notifyShopOwner(
  shopId: number,
  payload: {
    kind: string;
    title: string;
    body?: string;
    data?: Record<string, unknown>;
  },
): Promise<void> {
  const shop = await prisma.shop.findUnique({
    where: { id: shopId },
    select: { ownerUserId: true },
  });
  if (!shop) return;
  await Promise.all(
    [shop].map((o) =>
      notificationsService.create({
        userId: o.ownerUserId,
        kind: payload.kind,
        title: payload.title,
        body: payload.body,
        data: payload.data,
      }),
    ),
  );
}

export const purchaseRequestsController = new PurchaseRequestsController();
