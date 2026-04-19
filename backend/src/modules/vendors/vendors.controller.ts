import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { vendorsService } from './vendors.service.js';

const createVendorSchema = z.object({
  name: z.string().min(1).max(200),
  contactName: z.string().max(200).optional(),
  phone: z.string().max(20).optional(),
  email: z.string().email().max(200).optional(),
  address: z.string().max(500).optional(),
  gstin: z.string().max(20).optional(),
});

const updateVendorSchema = z
  .object({
    name: z.string().min(1).max(200).optional(),
    contactName: z.string().max(200).nullable().optional(),
    phone: z.string().max(20).nullable().optional(),
    email: z.string().email().max(200).nullable().optional(),
    address: z.string().max(500).nullable().optional(),
    gstin: z.string().max(20).nullable().optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, { message: 'At least one field required' });

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class VendorsController {
  async create(req: Request, res: Response): Promise<void> {
    const payload = createVendorSchema.parse(req.body);
    const vendor = await vendorsService.createVendor(payload);
    res.status(201).json(vendor);
  }

  async list(req: Request, res: Response): Promise<void> {
    const { page, limit, skip } = parsePagination(req);
    const search = (req.query.search as string) || '';
    const activeOnly = req.query.active !== 'false';

    const { vendors, total } = await vendorsService.listVendors({
      search,
      activeOnly,
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(vendors, total, { page, limit, skip }));
  }

  async getById(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const vendor = await vendorsService.getVendorById(id);
    if (!vendor) { res.status(404).json({ error: 'Vendor not found' }); return; }

    res.json(vendor);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const payload = updateVendorSchema.parse(req.body);
    const vendor = await vendorsService.updateVendor(id, payload);
    res.json(vendor);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    await vendorsService.deleteVendor(id);
    res.status(204).send();
  }
}

export const vendorsController = new VendorsController();
