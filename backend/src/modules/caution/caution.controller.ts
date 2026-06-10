import { Request, Response } from 'express';
import { z } from 'zod';
import { parsePagination, paginatedResponse } from '../../shared/http/pagination.js';
import { cautionService } from './caution.service.js';
import { cautionRequestsService, CautionRequestStatus } from './caution-requests.service.js';

const cautionModeSchema = z.enum([
  'CASH',
  'UPI',
  'NEFT',
  'RTGS',
  'CHEQUE',
  'CARD',
  'OTHER',
]);

const recordSchema = z.object({
  amount: z.number().positive(),
  mode: cautionModeSchema,
  modeReference: z.string().max(120).nullable().optional(),
  note: z.string().max(500).nullable().optional(),
});

const adjustSchema = z.object({
  invoiceId: z.number().int().positive(),
  amount: z.number().positive(),
  note: z.string().max(500).nullable().optional(),
});

const forfeitSchema = z
  .object({
    amount: z.number().positive(),
    gstTreatment: z.enum(['NONE', 'SUPPLY']),
    // Goods GST rate — drives the inclusive output-tax split on a SUPPLY
    // forfeit (Circular 178/2022 ¶11.3).
    taxRate: z.number().min(0).max(100).nullish(),
    note: z.string().max(500).nullable().optional(),
  })
  .refine((d) => d.gstTreatment !== 'SUPPLY' || d.taxRate != null, {
    message: 'taxRate is required when gstTreatment is SUPPLY',
    path: ['taxRate'],
  });

const rejectSchema = z.object({
  reviewNote: z.string().max(500).nullable().optional(),
});

const requestStatusSchema = z
  .enum(['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'])
  .optional();

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

export class CautionController {
  async history(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const partyId = parseId(req.params.id);
    if (!partyId) { res.status(400).json({ error: 'Invalid id' }); return; }

    const { page, limit, skip } = parsePagination(req);
    const result = await cautionService.history(shopId, partyId, { skip, take: limit });
    if (!result) { res.status(404).json({ error: 'Party not found' }); return; }

    res.json({
      balance: result.balance,
      ...paginatedResponse(result.entries, result.total, { page, limit, skip }),
    });
  }

  async deposit(req: Request, res: Response): Promise<void> {
    await this.record(req, res, 'DEPOSIT');
  }

  async refund(req: Request, res: Response): Promise<void> {
    await this.record(req, res, 'REFUND');
  }

  private async record(
    req: Request,
    res: Response,
    type: 'DEPOSIT' | 'REFUND',
  ): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const partyId = parseId(req.params.id);
    if (!partyId) { res.status(400).json({ error: 'Invalid id' }); return; }

    const payload = recordSchema.parse(req.body);
    const result = await cautionService.record(shopId, partyId, {
      type,
      ...payload,
      createdById: req.user?.sub ?? null,
    });
    if (!result) { res.status(404).json({ error: 'Party not found' }); return; }
    res.status(201).json(result);
  }

  async adjust(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const partyId = parseId(req.params.id);
    if (!partyId) { res.status(400).json({ error: 'Invalid id' }); return; }

    const payload = adjustSchema.parse(req.body);
    const result = await cautionService.adjust(shopId, partyId, {
      ...payload,
      createdById: req.user?.sub ?? null,
    });
    if (!result) { res.status(404).json({ error: 'Party not found' }); return; }
    res.status(201).json(result);
  }

  /// Forfeit (keep) part of a deposit on default. Records the taxable-income
  /// event with its GST-treatment flag; no Payment is created.
  async forfeit(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const partyId = parseId(req.params.id);
    if (!partyId) { res.status(400).json({ error: 'Invalid id' }); return; }

    const payload = forfeitSchema.parse(req.body);
    const result = await cautionService.forfeit(shopId, partyId, {
      ...payload,
      createdById: req.user?.sub ?? null,
    });
    if (!result) { res.status(404).json({ error: 'Party not found' }); return; }
    res.status(201).json(result);
  }

  // ── Party-initiated caution requests (merchant side) ──

  /// Shop-wide inbox. Defaults to PENDING when no status is given.
  async listShopRequests(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const { page, limit, skip } = parsePagination(req);
    const status =
      (requestStatusSchema.parse(req.query.status) as CautionRequestStatus | undefined) ??
      'PENDING';
    const { data, total } = await cautionRequestsService.listForShop(shopId, {
      status,
      skip,
      take: limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  /// Requests for one party (merchant side).
  async listPartyRequests(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const partyId = parseId(req.params.id);
    if (!partyId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const { page, limit, skip } = parsePagination(req);
    const status = requestStatusSchema.parse(req.query.status) as
      | CautionRequestStatus
      | undefined;
    const { data, total } = await cautionRequestsService.listForParty(shopId, partyId, {
      status,
      skip,
      take: limit,
    });
    res.json(paginatedResponse(data, total, { page, limit, skip }));
  }

  async approveRequest(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const requestId = parseId(req.params.reqId);
    if (!requestId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const result = await cautionRequestsService.approveCautionRequest(
      shopId,
      requestId,
      req.user!.sub,
    );
    res.json(result);
  }

  async rejectRequest(req: Request, res: Response): Promise<void> {
    const shopId = requireShopId(req, res);
    if (!shopId) return;
    const requestId = parseId(req.params.reqId);
    if (!requestId) { res.status(400).json({ error: 'Invalid id' }); return; }
    const { reviewNote } = rejectSchema.parse(req.body ?? {});
    const result = await cautionRequestsService.rejectRequest(
      shopId,
      requestId,
      req.user!.sub,
      reviewNote,
    );
    res.json(result);
  }
}

export const cautionController = new CautionController();
