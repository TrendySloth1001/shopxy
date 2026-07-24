import { Request, Response } from 'express';
import { z } from 'zod';
import { decodeId } from '../../shared/ids/publicId.js';
import { addressesService } from './addresses.service.js';

// PII-7 — normalise a contact phone toward E.164: strip spaces, dashes,
// dots and parentheses, keep a single optional leading '+'. Leaves the
// digits intact so the validator can count them.
const normalisePhone = (raw: string): string => {
  const trimmed = raw.trim();
  const hasPlus = trimmed.startsWith('+');
  const digits = trimmed.replace(/[^\d]/g, '');
  return hasPlus ? `+${digits}` : digits;
};

const addressSchema = z.object({
  label: z.string().max(40).nullable().optional(),
  // Trim and collapse internal whitespace so we don't persist " John  Doe ".
  fullName: z
    .string()
    .trim()
    .min(1)
    .max(120)
    .transform((s) => s.replace(/\s+/g, ' ')),
  // PII-7 — accept international numbers but normalise toward E.164 and
  // require a sane digit count (7–15 per the E.164 spec) so we don't
  // persist junk like "phone please call" that passed a bare length check.
  phone: z
    .string()
    .min(7)
    .max(20)
    .transform(normalisePhone)
    .refine((v) => /^\+?\d{7,15}$/.test(v), {
      message: 'Enter a valid phone number',
    }),
  line1: z.string().min(1).max(200),
  line2: z.string().max(200).nullable().optional(),
  city: z.string().min(1).max(80),
  state: z.string().min(1).max(80),
  pincode: z.string().min(3).max(12),
  landmark: z.string().max(120).nullable().optional(),
  isDefault: z.boolean().optional(),
});

const updateSchema = addressSchema.partial().refine(
  (d) => Object.keys(d).length > 0,
  { message: 'At least one field is required' },
);

export class AddressesController {
  async list(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const items = await addressesService.list(userId);
    res.json({ data: items });
  }

  async create(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const input = addressSchema.parse(req.body);
    const address = await addressesService.create(userId, input);
    res.status(201).json(address);
  }

  async update(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const id = decodeId(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'Invalid address id' });
      return;
    }
    const input = updateSchema.parse(req.body);
    const result = await addressesService.update(userId, id, input);
    if (!result.ok) {
      res.status(404).json({ error: 'Address not found' });
      return;
    }
    res.json(result.address);
  }

  async setDefault(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const id = decodeId(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'Invalid address id' });
      return;
    }
    const out = await addressesService.setDefault(userId, id);
    if (out === 'not_found') {
      res.status(404).json({ error: 'Address not found' });
      return;
    }
    res.status(204).end();
  }

  async delete(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const id = decodeId(req.params.id);
    if (id === null) {
      res.status(400).json({ error: 'Invalid address id' });
      return;
    }
    const out = await addressesService.delete(userId, id);
    if (out === 'not_found') {
      res.status(404).json({ error: 'Address not found' });
      return;
    }
    res.status(204).end();
  }
}

export const addressesController = new AddressesController();
