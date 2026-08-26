import { Request, Response } from 'express';
import { decodeId } from '../../shared/ids/publicId.js';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { z } from 'zod';
import * as cashier from './cashier.service.js';
import * as returns from './returns.service.js';
import { authorizeOverride, verifyOverride } from './override.js';
import { hasRight, POS_OVERRIDE_RIGHT } from '../../shared/http/permissions.js';

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

  async report(req: Request, res: Response): Promise<void> {
    const r = await cashier.xReport(req.shopId!, req.user!.sub);
    if (!r) {
      res.status(404).json({ error: 'No open shift' });
      return;
    }
    res.json(r);
  },

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

  async shiftReport(req: Request, res: Response): Promise<void> {
    const id = decodeId(req.params.id);
    if (id === null) {
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

  async returnable(req: Request, res: Response): Promise<void> {
    const invoiceId = decodeId(req.params.invoiceId);
    if (invoiceId === null) {
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
  originalInvoiceId: zPublicId,
  refundMode: z.enum(['CASH', 'UPI', 'CARD', 'OTHER']),
  lines: z
    .array(z.object({ productId: zPublicId, quantity: z.number().positive().max(100_000) }))
    .min(1)
    .max(200),
  override: z.string().optional(),
});

const authorizeSchema = z.object({
  email: z.string().trim().email().max(200),
  password: z.string().min(1).max(200),
  saleId: zPublicId,
  op: z.enum(['setLineDiscount', 'setUnitPrice', 'setHeaderDiscount', 'void', 'return']),
});
