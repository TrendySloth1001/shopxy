import { Request, Response } from 'express';
import { z } from 'zod';
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
      .or(z.string().date())
      .optional(),
    partyId: z.number().int().positive().nullable().optional(),
    vendorId: z.number().int().positive().nullable().optional(),
    invoiceId: z.number().int().positive().nullable().optional(),
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
  partyId: z.coerce.number().int().positive().optional(),
  vendorId: z.coerce.number().int().positive().optional(),
  invoiceId: z.coerce.number().int().positive().optional(),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
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
    const ok = await paymentsService.deletePayment(shopId, id);
    if (!ok) {
      res.status(404).json({ error: 'Payment not found' });
      return;
    }
    res.status(204).send();
  }
}

export const paymentsController = new PaymentsController();
