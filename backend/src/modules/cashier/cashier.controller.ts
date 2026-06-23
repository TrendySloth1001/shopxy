import { Request, Response } from 'express';
import { z } from 'zod';
import * as cashier from './cashier.service.js';
import * as returns from './returns.service.js';
import { authorizeOverride, verifyOverride } from './override.js';
import { hasRight, POS_OVERRIDE_RIGHT } from '../../shared/http/permissions.js';

/// Cashier control center REST endpoints (mounted at /me/cashier, invoices area).
/// The shift lifecycle is low-frequency and stateful, so it's plain REST rather
/// than riding the POS WebSocket.

// CASH-7 — cash inputs are money: constrain to whole paise (2dp) at the
// boundary so a 3rd-decimal value is rejected here rather than silently
// rounded by the Decimal(12,2)/(15,2) column on store. multipleOf(0.01)
// rejects e.g. 100.999; the service still rounds defensively in Decimal.
const paise = (n: z.ZodNumber) => n.multipleOf(0.01);
const openSchema = z.object({ openingFloat: paise(z.number().min(0).max(10_000_000)).default(0) });
const movementSchema = z.object({
  type: z.enum(['PAY_IN', 'PAY_OUT', 'DROP']),
  amount: paise(z.number().positive().max(10_000_000)),
  reason: z.string().trim().max(200).optional(),
});
const closeSchema = z.object({
  countedCash: paise(z.number().min(0).max(100_000_000)),
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

  /// Shift history (Z-receipt list). A plain cashier sees only their own
  /// shifts; an owner/manager (the override right) sees every employee's,
  /// labelled by name + email.
  async shifts(req: Request, res: Response): Promise<void> {
    const limit = Number(req.query.limit) || 30;
    const seesAll = hasRight(req.user!.shopRole, req.user!.shopPermissions, POS_OVERRIDE_RIGHT);
    res.json(
      await cashier.listShifts(req.shopId!, {
        limit,
        openedById: seesAll ? undefined : req.user!.sub,
      }),
    );
  },

  /// Full Z-report for a past (or open) shift. Same scope as the list: a
  /// cashier may only open their own; managers/owners may open any.
  async shiftReport(req: Request, res: Response): Promise<void> {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      res.status(400).json({ error: 'Invalid shift id' });
      return;
    }
    const seesAll = hasRight(req.user!.shopRole, req.user!.shopPermissions, POS_OVERRIDE_RIGHT);
    const r = await cashier.report(req.shopId!, id, {
      openedById: seesAll ? undefined : req.user!.sub,
    });
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
    // Returns are a privileged action: require the override right or a manager
    // grant. CASH-2 — the grant is single-use and bound to THIS original sale +
    // the 'return' op, so it can't be replayed or reused for another action.
    const allowed =
      hasRight(req.user!.shopRole, req.user!.shopPermissions, POS_OVERRIDE_RIGHT) ||
      (await verifyOverride(parsed.data.override, req.shopId!, parsed.data.originalInvoiceId, 'return')) != null;
    if (!allowed) {
      res.status(403).json({ error: 'Manager authorisation required to process a return.', code: 'OVERRIDE_REQUIRED' });
      return;
    }
    const r = await returns.returnSale(req.shopId!, req.user!.sub, parsed.data);
    if (isErr(r)) {
      res.status(400).json(r);
      return;
    }
    res.json(r);
  },

  /// Manager-authorise a privileged till action — verify credentials + privilege,
  /// return a short-lived grant the cashier replays on the action.
  async authorize(req: Request, res: Response): Promise<void> {
    const parsed = authorizeSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Enter the manager email and password' });
      return;
    }
    const r = await authorizeOverride(
      req.shopId!,
      parsed.data.email,
      parsed.data.password,
      parsed.data.saleId,
      parsed.data.op,
    );
    if (isErr(r)) {
      res.status(403).json(r);
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
  /// A manager-authorisation grant, when the cashier lacks the override right.
  override: z.string().optional(),
});

const authorizeSchema = z.object({
  email: z.string().trim().email().max(200),
  password: z.string().min(1).max(200),
  /// CASH-2 — the grant is bound to one sale (the POS saleId, or the original
  /// invoice id for a return) + one privileged op, so it is single-use and
  /// can't be replayed against a different action.
  saleId: z.number().int().positive(),
  op: z.enum(['setLineDiscount', 'setUnitPrice', 'setHeaderDiscount', 'void', 'return']),
});
