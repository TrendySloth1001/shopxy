import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import {
  RETURN_REASONS,
  returnsService,
  type ReturnReason,
} from './returns.service.js';
import { notificationsService } from '../notifications/notifications.service.js';

const submitSchema = z.object({
  childId: z.number().int().positive(),
  note: z.string().max(500).optional(),
  items: z
    .array(
      z.object({
        purchaseRequestItemId: z.number().int().positive(),
        quantity: z.number().positive(),
        reason: z.enum(RETURN_REASONS as unknown as [ReturnReason, ...ReturnReason[]]),
      }),
    )
    .min(1)
    .max(50),
});

const decisionSchema = z.object({ note: z.string().max(500).optional() });
// Refunds always go back to the customer's original payment instrument now —
// there is no method choice (wallet/store-credit was removed as it's illegal
// for an online payment). `method` is accepted-but-ignored for back-compat with
// older clients that still send it.
const refundSchema = z.object({
  method: z.string().optional(),
  note: z.string().max(500).optional(),
});

const RETURN_STATUSES = [
  'REQUESTED',
  'APPROVED',
  'REJECTED',
  'PICKED_UP',
  'RECEIVED',
  'REFUNDED',
  'CANCELLED',
] as const;
const listQuerySchema = z.object({
  status: z.enum(RETURN_STATUSES).optional(),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class ReturnsController {
  // ── Customer ──────────────────────────────────────────────────────

  /// POST /me/orders/:parentId/returns
  async submit(req: Request, res: Response): Promise<void> {
    const parentId = parseId(req.params.parentId);
    if (!parentId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = submitSchema.parse(req.body);
    const result = await returnsService.submit({
      customerUserId: req.user!.sub,
      parentId,
      childId: payload.childId,
      note: payload.note,
      items: payload.items.map((i) => ({
        purchaseRequestItemId: i.purchaseRequestItemId,
        quantity: i.quantity,
        reason: i.reason,
      })),
    });
    if ('error' in result) {
      const status =
        result.error === 'NOT_FOUND' ? 404
        : result.error === 'ALREADY_REQUESTED' ? 409
        : result.error === 'RETURNS_DISABLED' ? 422
        : result.error === 'WINDOW_EXPIRED' ? 422
        : 400;
      res.status(status).json({ error: result.error });
      return;
    }
    res.status(201).json({ id: result.id });
  }

  async list(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const { data, total } = await returnsService.listForCustomer({
      userId: req.user!.sub,
      skip,
      limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async getOwn(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const row = await returnsService.getForCustomer({
      userId: req.user!.sub,
      id,
    });
    if (!row) { res.status(404).json({ error: 'Return not found' }); return; }
    res.json(row);
  }

  async cancel(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const result = await returnsService.cancelByCustomer({
      userId: req.user!.sub,
      id,
    });
    if ('error' in result) {
      const status =
        result.error === 'NOT_FOUND' ? 404
        : result.error === 'NOT_OWNED' ? 403
        : 409;
      res.status(status).json({ error: result.error });
      return;
    }
    res.status(204).send();
  }

  // ── Merchant ──────────────────────────────────────────────────────

  async listMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const parsedQ = listQuerySchema.safeParse(req.query);
    if (!parsedQ.success) {
      res.status(400).json({ error: 'Invalid status', issues: parsedQ.error.issues });
      return;
    }
    const { page, limit, skip } = parsePagination(req);
    const { data, total } = await returnsService.listForMerchant({
      shopId,
      status: parsedQ.data.status,
      skip,
      limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async getMerchant(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const row = await returnsService.getForMerchant({ shopId, id });
    if (!row) { res.status(404).json({ error: 'Return not found' }); return; }
    res.json(row);
  }

  private async _runTransition(
    req: Request,
    res: Response,
    fn: (opts: {
      shopId: number;
      id: number;
      actorId: number;
      note?: string | null;
    }) => Promise<{ ok: true } | { error: 'NOT_FOUND' | 'BAD_STATE' }>,
    successKind?: { kind: string; title: string; body: (id: number) => string },
  ): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = decisionSchema.parse(req.body ?? {});
    const result = await fn({
      shopId,
      id,
      actorId: req.user!.sub,
      note: payload.note ?? null,
    });
    if ('error' in result) {
      res.status(result.error === 'NOT_FOUND' ? 404 : 409).json({ error: result.error });
      return;
    }
    if (successKind) {
      const row = await returnsService.getForMerchant({ shopId, id });
      if (row) {
        void notificationsService
          .create({
            userId: row.customerUserId,
            kind: successKind.kind,
            title: successKind.title,
            body: successKind.body(id),
            data: { returnId: id },
          })
          .catch(() => {});
      }
    }
    res.status(204).send();
  }

  approve = (req: Request, res: Response) =>
    this._runTransition(req, res, (o) => returnsService.approve(o), {
      kind: 'RETURN_APPROVED',
      title: 'Return approved',
      body: (id) => `Return #${id} has been approved.`,
    });

  reject = (req: Request, res: Response) =>
    this._runTransition(req, res, (o) => returnsService.reject(o), {
      kind: 'RETURN_REJECTED',
      title: 'Return rejected',
      body: (id) => `Return #${id} was not accepted.`,
    });

  pickedUp = (req: Request, res: Response) =>
    this._runTransition(req, res, (o) => returnsService.pickedUp(o), {
      kind: 'RETURN_UPDATE',
      title: 'Return update',
      body: (id) => `Return #${id} has been picked up.`,
    });

  received = (req: Request, res: Response) =>
    this._runTransition(req, res, (o) => returnsService.received(o), {
      kind: 'RETURN_UPDATE',
      title: 'Return update',
      body: (id) => `Return #${id} has been received.`,
    });

  async refund(req: Request, res: Response): Promise<void> {
    const shopId = req.user?.shopId;
    if (!shopId) {
      res.status(403).json({ error: 'This account has no shop linked.' });
      return;
    }
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const payload = refundSchema.parse(req.body ?? {});
    const result = await returnsService.refund({
      shopId,
      id,
      actorId: req.user!.sub,
      note: payload.note ?? null,
    });
    if ('error' in result) {
      res.status(result.error === 'NOT_FOUND' ? 404 : 409).json({ error: result.error });
      return;
    }
    const row = await returnsService.getForMerchant({ shopId, id });
    if (row) {
      // A COD/never-captured order has no online payment to reverse — the
      // merchant settles that offline, so don't promise the customer a gateway
      // refund that isn't coming. Online orders get the refund-to-source notice.
      const refunded = result.refundStatus === 'REFUNDED';
      void notificationsService
        .create({
          userId: row.customerUserId,
          kind: 'RETURN_REFUNDED',
          title: refunded ? 'Refund on its way' : 'Return completed',
          body: refunded
            ? `₹${result.refundAmount.toFixed(0)} is being refunded to your original payment method.`
            : `Your return for #${id} has been processed.`,
          data: { returnId: id, refundStatus: result.refundStatus },
        })
        .catch(() => {});
    }
    res.status(200).json(result);
  }
}

export const returnsController = new ReturnsController();
