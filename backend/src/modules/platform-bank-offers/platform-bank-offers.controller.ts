import { Request, Response } from 'express';
import { z } from 'zod';
import { platformBankOffersService } from './platform-bank-offers.service.js';

/// Bank short-codes mirror the customer PDP's recognised set. Listed
/// here so the admin form can offer a dropdown of exactly the banks
/// the renderer can decorate with a brand-coloured monogram.
const BANKS = [
  'HDFC',
  'ICICI',
  'SBI',
  'AXIS',
  'KOTAK',
  'AMEX',
  'YES',
  'HSBC',
  'SC',
  'IDFC',
  'BOB',
  'RBL',
] as const;

const CARD_TYPES = [
  'CREDIT',
  'DEBIT',
  'CREDIT_DEBIT',
  'NET_BANKING',
  'EMI',
  'ANY',
] as const;

/// Base object — kept separate from the refinements so the update
/// schema can derive `.partial()` from it (ZodEffects has no .partial()).
const baseSchema = z.object({
  bank: z.enum(BANKS),
  cardType: z.enum(CARD_TYPES),
  discountType: z.enum(['PERCENT', 'FLAT']),
  discountValue: z.number().positive(),
  maxDiscount: z.number().positive().nullable().optional(),
  minOrderAmount: z.number().min(0).optional(),
  terms: z.string().max(280).nullable().optional(),
  validFrom: z.string().datetime(),
  validUntil: z.string().datetime(),
  isActive: z.boolean().optional(),
});

const createSchema = baseSchema
  .refine(
    (d) =>
      d.discountType === 'FLAT' ||
      (d.discountValue > 0 && d.discountValue <= 100),
    { message: 'PERCENT discount must be 1–100' },
  )
  .refine((d) => new Date(d.validFrom) < new Date(d.validUntil), {
    message: 'validFrom must be earlier than validUntil',
  });

const updateSchema = baseSchema.partial().refine(
  (d) => {
    if (d.validFrom !== undefined && d.validUntil !== undefined) {
      return new Date(d.validFrom) < new Date(d.validUntil);
    }
    return true;
  },
  { message: 'validFrom must be earlier than validUntil' },
);

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class PlatformBankOffersController {
  /// GET /admin/platform-bank-offers — full list, regardless of state.
  async listAdmin(_req: Request, res: Response): Promise<void> {
    const data = await platformBankOffersService.listForAdmin();
    res.json({ data });
  }

  async getOne(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const row = await platformBankOffersService.getById(id);
    if (!row) {
      res.status(404).json({ error: 'Offer not found' });
      return;
    }
    res.json(row);
  }

  async create(req: Request, res: Response): Promise<void> {
    const payload = createSchema.parse(req.body);
    const row = await platformBankOffersService.create({
      bank: payload.bank,
      cardType: payload.cardType,
      discountType: payload.discountType,
      discountValue: payload.discountValue,
      maxDiscount: payload.maxDiscount ?? null,
      minOrderAmount: payload.minOrderAmount ?? 0,
      terms: payload.terms ?? null,
      validFrom: new Date(payload.validFrom),
      validUntil: new Date(payload.validUntil),
      isActive: payload.isActive ?? true,
    });
    res.status(201).json(row);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateSchema.parse(req.body);
    const { validFrom, validUntil, ...rest } = payload;
    const row = await platformBankOffersService.update(id, {
      ...rest,
      ...(validFrom !== undefined && { validFrom: new Date(validFrom) }),
      ...(validUntil !== undefined && { validUntil: new Date(validUntil) }),
    });
    if (!row) {
      res.status(404).json({ error: 'Offer not found' });
      return;
    }
    res.json(row);
  }

  async deactivate(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await platformBankOffersService.deactivate(id);
    if (!ok) {
      res.status(404).json({ error: 'Offer not found' });
      return;
    }
    res.status(204).send();
  }
}

export const platformBankOffersController =
  new PlatformBankOffersController();

export { BANKS, CARD_TYPES };
