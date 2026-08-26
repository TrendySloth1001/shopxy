import { Request, Response } from 'express';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { z } from 'zod';
import { decodeId } from '../../shared/ids/publicId.js';
import {
  parsePagination,
  paginatedResponse,
} from '../../shared/http/pagination.js';
import { paymentsService } from './payments.service.js';

const paymentModeSchema = z.enum([
  'CASH',
  'UPI',
  'NEFT',
  'RTGS',
  'CHEQUE',
  'CARD',
  'OTHER',
]);

const createPaymentSchema = z
  .object({
    type: z.enum(['RECEIPT', 'PAYMENT']),
    amount: z.number().positive(),
    mode: paymentModeSchema,
    modeReference: z.string().max(120).nullable().optional(),
    paymentDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().datetime({ local: true }))
      .or(z.string().date())
      .optional(),
    partyId: zPublicId.nullable().optional(),
    vendorId: zPublicId.nullable().optional(),
    invoiceId: zPublicId.nullable().optional(),
    note: z.string().max(500).nullable().optional(),
  })
  .refine(
    (d) => (d.partyId != null) !== (d.vendorId != null),
    { message: 'Exactly one of partyId / vendorId must be set' },
  )
  .refine(
    (d) =>
      (d.type === 'RECEIPT' && d.partyId != null) ||
      (d.type === 'PAYMENT' && d.vendorId != null),
    {
      message:
        'RECEIPT must have partyId; PAYMENT must have vendorId',
    },
  );

const listPaymentsSchema = z.object({
  partyId: zPublicId.optional(),
  vendorId: zPublicId.optional(),
  invoiceId: zPublicId.optional(),
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

export class PaymentsController {
  async create(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const payload = createPaymentSchema.parse(req.body);
    const rawKey = req.get('x-idempotency-key') ?? req.get('X-Idempotency-Key');
    const idempotencyKey =
      typeof rawKey === 'string' && rawKey.length > 0 && rawKey.length <= 120
        ? rawKey
        : null;
    try {
      const payment = await paymentsService.createPayment({
        shopId,
        type: payload.type,
        amount: payload.amount,
        mode: payload.mode,
        modeReference: payload.modeReference ?? null,
        paymentDate: payload.paymentDate
          ? new Date(payload.paymentDate)
          : undefined,
        partyId: payload.partyId ?? null,
        vendorId: payload.vendorId ?? null,
        invoiceId: payload.invoiceId ?? null,
        note: payload.note ?? null,
        createdById: req.user?.sub ?? null,
        idempotencyKey,
      });
      res.status(201).json(payment);
    } catch (err) {
      const message =
        err instanceof Error ? err.message : 'Failed to record payment';
      res.status(400).json({ error: message });
    }
  }

  async list(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const filters = listPaymentsSchema.parse(req.query);
    const { page, limit, skip } = parsePagination(req);

    const { payments, total } = await paymentsService.listPayments(shopId, {
      partyId: filters.partyId ?? null,
      vendorId: filters.vendorId ?? null,
      invoiceId: filters.invoiceId ?? null,
      page,
      limit,
      skip,
    });
    res.json(paginatedResponse(payments, total, { page, limit, skip }));
  }

  async getById(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payment = await paymentsService.getPaymentById(shopId, id);
    if (!payment) {
      res.status(404).json({ error: 'Payment not found' });
      return;
    }
    res.json(payment);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const reason =
      (typeof req.body?.reason === 'string' && req.body.reason) ||
      (typeof req.query?.reason === 'string' && req.query.reason) ||
      null;
    const result = await paymentsService.voidPayment(shopId, id, req.user?.sub ?? null, reason);
    if (result === false) {
      res.status(404).json({ error: 'Payment not found' });
      return;
    }
    if (result === 'PLATFORM_COLLECTED') {
      res.status(409).json({
        error:
          'This receipt backs a payment the platform already collected (customer wallet/online or a POS QR settlement). Issue a refund or credit note instead of voiding it.',
      });
      return;
    }
    res.status(204).send();
  }
}

export const paymentsController = new PaymentsController();
