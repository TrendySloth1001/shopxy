import { Request, Response } from 'express';
import { z } from 'zod';
import * as cashier from './cashier.service.js';
import * as returns from './returns.service.js';

/// Cashier control center REST endpoints (mounted at /me/cashier, invoices area).
/// The shift lifecycle is low-frequency and stateful, so it's plain REST rather
/// than riding the POS WebSocket.

const openSchema = z.object({ openingFloat: z.number().min(0).max(10_000_000).default(0) });
const movementSchema = z.object({
  type: z.enum(['PAY_IN', 'PAY_OUT', 'DROP']),
  amount: z.number().positive().max(10_000_000),
  reason: z.string().trim().max(200).optional(),
});
const closeSchema = z.object({
  countedCash: z.number().min(0).max(100_000_000),
  note: z.string().trim().max(500).optional(),
});

const isErr = (r: unknown): r is { error: string } =>
  typeof r === 'object' && r !== null && 'error' in r;

export const cashierController = {
  /// Current open shift (or null) for the caller — boots the control center.
  async current(req: Request, res: Response): Promise<void> {
    const shift = await cashier.getOpenShift(req.shopId!, req.user!.sub);
    const report = shift ? await cashier.xReport(req.shopId!, req.user!.sub) : null;
    res.json({ shift, report });
  },

  async open(req: Request, res: Response): Promise<void> {
    const parsed = openSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid opening float' });
      return;
    }
    const r = await cashier.openShift(req.shopId!, req.user!.sub, parsed.data.openingFloat);
    if (isErr(r)) {
      res.status(400).json(r);
      return;
    }
    res.json(r);
  },

  async movement(req: Request, res: Response): Promise<void> {
    const parsed = movementSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid cash movement' });
      return;
    }
    const r = await cashier.addCashMovement(req.shopId!, req.user!.sub, parsed.data);
    if (isErr(r)) {
      res.status(400).json(r);
      return;
    }
    res.json(r);
  },

  async close(req: Request, res: Response): Promise<void> {
    const parsed = closeSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid close payload' });
      return;
    }
    const r = await cashier.closeShift(req.shopId!, req.user!.sub, parsed.data);
    if (isErr(r)) {
      res.status(400).json(r);
      return;
    }
    res.json(r);
  },

  /// Live X-report for the current open shift.
  async report(req: Request, res: Response): Promise<void> {
    const r = await cashier.xReport(req.shopId!, req.user!.sub);
    if (!r) {
      res.status(404).json({ error: 'No open shift' });
      return;
    }
    res.json(r);
  },

  /// Shift history (Z-receipt list).
  async shifts(req: Request, res: Response): Promise<void> {
    const limit = Number(req.query.limit) || 30;
    res.json(await cashier.listShifts(req.shopId!, limit));
  },

  /// Full Z-report for a past (or open) shift.
  async shiftReport(req: Request, res: Response): Promise<void> {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      res.status(400).json({ error: 'Invalid shift id' });
      return;
    }
    const r = await cashier.report(req.shopId!, id);
    if (isErr(r)) {
      res.status(404).json(r);
      return;
    }
    res.json(r);
  },

  /// The original sale + per-line returnable quantities, for the return screen.
  async returnable(req: Request, res: Response): Promise<void> {
    const invoiceId = Number(req.params.invoiceId);
    if (!Number.isInteger(invoiceId) || invoiceId <= 0) {
      res.status(400).json({ error: 'Invalid invoice id' });
      return;
    }
    const r = await returns.getReturnable(req.shopId!, invoiceId);
    if (isErr(r)) {
      res.status(404).json(r);
      return;
    }
    res.json(r);
  },

  async processReturn(req: Request, res: Response): Promise<void> {
    const parsed = returnSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid return payload' });
      return;
    }
    const r = await returns.returnSale(req.shopId!, req.user!.sub, parsed.data);
    if (isErr(r)) {
      res.status(400).json(r);
      return;
    }
    res.json(r);
  },
};

const returnSchema = z.object({
  originalInvoiceId: z.number().int().positive(),
  refundMode: z.enum(['CASH', 'UPI', 'CARD', 'OTHER']),
  lines: z
    .array(z.object({ productId: z.number().int().positive(), quantity: z.number().positive().max(100_000) }))
    .min(1)
    .max(200),
});
