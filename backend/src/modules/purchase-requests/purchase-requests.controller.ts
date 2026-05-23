import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { purchaseRequestsService } from './purchase-requests.service.js';
import { notificationsService } from '../notifications/notifications.service.js';
import prisma from '../../infra/db/prisma.js';

const createSchema = z.object({
  items: z
    .array(
      z.object({
        productId: z.number().int().positive(),
        quantity: z.number().positive(),
      }),
    )
    .min(1),
  note: z.string().max(500).optional(),
});

const decisionSchema = z.object({ note: z.string().max(500).optional() });

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class PurchaseRequestsController {
  // ── Customer-facing ────────────────────────────────────────────────

  async createForCustomer(req: Request, res: Response): Promise<void> {
    const payload = createSchema.parse(req.body);
    const userId = req.user!.sub;

    const result = await purchaseRequestsService.createForCustomer({
      customerUserId: userId,
      items: payload.items,
      note: payload.note,
    });
    if ('error' in result) {
      res.status(400).json({ error: result.error });
      return;
    }

    // Notify every merchant so any owner role can pick it up. Best-effort
    // — a notification fail must not block the order from being saved.
    void notifyAllMerchants({
      kind: 'ORDER_RECEIVED',
      title: 'New order',
      body: `Order #${result.request.id}`,
      data: { requestId: result.request.id },
    }).catch(() => {});

    res.status(201).json(result.request);
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
    if (result.count === 0) {
      res.status(409).json({ error: 'Order cannot be cancelled' });
      return;
    }
    res.status(204).send();
  }

  // ── Merchant-facing ────────────────────────────────────────────────

  async listForMerchant(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const status = req.query.status as string | undefined;
    const { data, total } = await purchaseRequestsService.listForMerchant({
      status,
      skip,
      limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async pendingCount(_req: Request, res: Response): Promise<void> {
    const count = await purchaseRequestsService.pendingCount();
    res.json({ count });
  }

  async getForMerchant(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const request = await purchaseRequestsService.getForMerchant(id);
    if (!request) { res.status(404).json({ error: 'Order not found' }); return; }
    res.json(request);
  }

  async confirm(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = decisionSchema.parse(req.body ?? {});

    const result = await purchaseRequestsService.confirmRequest({
      requestId: id,
      decidedById: req.user!.sub,
      note: payload.note,
    });
    if ('error' in result) {
      res.status(409).json({ error: result.error });
      return;
    }

    const request = await purchaseRequestsService.getForMerchant(id);
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
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = decisionSchema.parse(req.body ?? {});

    const result = await purchaseRequestsService.rejectRequest({
      requestId: id,
      decidedById: req.user!.sub,
      note: payload.note,
    });
    if ('error' in result) {
      res.status(409).json({ error: result.error });
      return;
    }

    const request = await purchaseRequestsService.getForMerchant(id);
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
/// OWNER). Used when a customer submits an order; lets any logged-in
/// merchant see the inbox badge update.
async function notifyAllMerchants(payload: {
  kind: string;
  title: string;
  body?: string;
  data?: Record<string, unknown>;
}): Promise<void> {
  const owners = await prisma.user.findMany({
    where: { role: 'OWNER', isActive: true },
    select: { id: true },
  });
  await Promise.all(
    owners.map((o) =>
      notificationsService.create({
        userId: o.id,
        kind: payload.kind,
        title: payload.title,
        body: payload.body,
        data: payload.data,
      }),
    ),
  );
}

export const purchaseRequestsController = new PurchaseRequestsController();
