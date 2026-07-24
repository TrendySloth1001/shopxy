import { Request, Response } from 'express';
import { decodeId } from '../../shared/ids/publicId.js';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { vendorsService } from './vendors.service.js';
import { paymentsService } from '../payments/payments.service.js';
import { contactChangeLogService } from '../contact-change-log/contact-change-log.service.js';

const stateCodeSchema = z.string().regex(/^\d{2}$/, 'must be 2-digit GST state code');

const createVendorSchema = z.object({
  name: z.string().min(1).max(200),
  contactName: z.string().max(200).optional(),
  phone: z.string().max(20).optional(),
  email: z.string().email().max(200).optional(),
  address: z.string().max(500).optional(),
  city: z.string().max(120).optional(),
  state: z.string().max(120).optional(),
  stateCode: stateCodeSchema.optional(),
  pinCode: z.string().max(10).optional(),
  panNumber: z.string().max(20).optional(),
  gstin: z.string().max(20).optional(),
});

const updateVendorSchema = z
  .object({
    name: z.string().min(1).max(200).optional(),
    contactName: z.string().max(200).nullable().optional(),
    phone: z.string().max(20).nullable().optional(),
    email: z.string().email().max(200).nullable().optional(),
    address: z.string().max(500).nullable().optional(),
    city: z.string().max(120).nullable().optional(),
    state: z.string().max(120).nullable().optional(),
    stateCode: stateCodeSchema.nullable().optional(),
    pinCode: z.string().max(10).nullable().optional(),
    panNumber: z.string().max(20).nullable().optional(),
    gstin: z.string().max(20).nullable().optional(),
    isActive: z.boolean().optional(),
  })
  .refine((d) => Object.keys(d).length > 0, { message: 'At least one field required' });

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

export class VendorsController {
  async create(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const payload = createVendorSchema.parse(req.body);
    const vendor = await vendorsService.createVendor(shopId, payload);
    res.status(201).json(vendor);
  }

  async list(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { page, limit, skip } = parsePagination(req);
    const search = (req.query.search as string) || '';
    const activeOnly = req.query.active !== 'false';

    const { vendors, total } = await vendorsService.listVendors(shopId, {
      search,
      activeOnly,
      page,
      limit,
      skip,
    });

    res.json(paginatedResponse(vendors, total, { page, limit, skip }));
  }

  async getById(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const vendor = await vendorsService.getVendorById(shopId, id);
    if (!vendor) { res.status(404).json({ error: 'Vendor not found' }); return; }

    res.json(vendor);
  }

  async overview(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const overview = await vendorsService.getVendorOverview(shopId, id);
    if (!overview) { res.status(404).json({ error: 'Vendor not found' }); return; }

    res.json(overview);
  }

  async update(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const payload = updateVendorSchema.parse(req.body);
    const vendor = await vendorsService.updateVendor(
      shopId,
      id,
      payload,
      req.user?.sub ?? null,
    );
    if (!vendor) { res.status(404).json({ error: 'Vendor not found' }); return; }
    res.json(vendor);
  }

  async ledger(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const ledger = await paymentsService.vendorLedger(shopId, id);
    if (!ledger) { res.status(404).json({ error: 'Vendor not found' }); return; }
    res.json(ledger);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }

    const result = await vendorsService.deleteVendor(shopId, id);
    if (!result) { res.status(404).json({ error: 'Vendor not found' }); return; }
    res.status(204).send();
  }

  async changes(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const id = parseId(req.params.id);
    if (!id) { res.status(400).json({ error: 'Invalid id' }); return; }
    const owned = await vendorsService.getVendorById(shopId, id);
    if (!owned) { res.status(404).json({ error: 'Vendor not found' }); return; }
    const params = parsePagination(req);
    const { rows, total } = await contactChangeLogService.listForEntity({
      shopId,
      entityType: 'VENDOR',
      entityId: id,
      ...params,
    });
    res.json(paginatedResponse(rows, total, params));
  }
}

export const vendorsController = new VendorsController();
