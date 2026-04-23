import { Request, Response } from 'express';
import { z } from 'zod';
import { challansService } from './challans.service.js';

const challanItemSchema = z.object({
  productId: z.number().int().positive(),
  quantity: z.number().positive(),
});

const createChallanSchema = z
  .object({
    partyId: z.number().int().positive().optional(),
    partyName: z.string().min(1).optional(),
    partyPhone: z.string().optional(),
    note: z.string().optional(),
    items: z.array(challanItemSchema).min(1),
  })
  .refine((d) => d.partyId !== undefined || (d.partyName && d.partyName.length > 0), {
    message: 'Either partyId or partyName is required',
    path: ['partyName'],
  });

const convertSchema = z.object({
  customerName: z.string().optional(),
  customerGstin: z.string().optional(),
  discount: z.number().min(0).optional(),
  note: z.string().optional(),
});

export async function createChallan(req: Request, res: Response) {
  const parsed = createChallanSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await challansService.createChallan(parsed.data);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(201).json(result.challan);
}

export async function listChallans(req: Request, res: Response) {
  const status = typeof req.query.status === 'string' ? req.query.status : undefined;
  const search = typeof req.query.search === 'string' ? req.query.search : '';
  const page = Math.max(1, Number(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 20));
  const skip = (page - 1) * limit;

  const { challans, total } = await challansService.listChallans({ status, search, page, limit, skip });
  res.json({ data: challans, pagination: { total, page, limit } });
}

export async function getChallan(req: Request, res: Response) {
  const id = Number(req.params.id);
  const challan = await challansService.getChallanById(id);
  if (!challan) {
    res.status(404).json({ error: 'Challan not found' });
    return;
  }
  res.json(challan);
}

export async function cancelChallan(req: Request, res: Response) {
  const id = Number(req.params.id);
  const result = await challansService.cancelChallan(id);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(204).end();
}

export async function convertToInvoice(req: Request, res: Response) {
  const id = Number(req.params.id);
  const parsed = convertSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.flatten() });
    return;
  }
  const result = await challansService.convertToInvoice(id, parsed.data);
  if ('error' in result) {
    res.status(400).json({ error: result.error });
    return;
  }
  res.status(201).json(result.invoice);
}
