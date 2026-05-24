import { Request, Response } from 'express';
import { BrandSpotlightStatus } from '@prisma/client';
import { z } from 'zod';
import { brandSpotlightService } from './brand-spotlight.service.js';
import { isValidCtaTarget } from '../../shared/cta-target.js';

const STATUSES: [BrandSpotlightStatus, ...BrandSpotlightStatus[]] = [
  'PENDING',
  'APPROVED',
  'REJECTED',
];

const hexColor = z
  .string()
  .regex(/^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/, 'Must be hex like #RRGGBB');

const imageRef = z
  .string()
  .min(1)
  .max(2048)
  .refine((v) => /^https?:\/\//i.test(v) || v.startsWith('/'), {
    message: 'Must be an http(s) URL or a server-relative path',
  });

const ctaTargetSchema = z
  .string()
  .max(2048)
  .refine(isValidCtaTarget, 'Invalid CTA target');

const submitSchema = z
  .object({
    dealLabel: z.string().min(1).max(80),
    subtitle: z.string().max(240).nullable().optional(),
    heroImageUrl: imageRef,
    bgColor: hexColor,
    accentColor: hexColor.nullable().optional(),
    ctaTarget: ctaTargetSchema.nullable().optional(),
    startAt: z.string().datetime(),
    endAt: z.string().datetime(),
  })
  .refine((d) => new Date(d.endAt) > new Date(d.startAt), {
    message: 'endAt must be after startAt',
    path: ['endAt'],
  });

const rejectSchema = z.object({ reason: z.string().min(1).max(500) });

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class BrandSpotlightController {
  // ── Merchant ─────────────────────────────────────────────────────

  async submit(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const payload = submitSchema.parse(req.body);
    const created = await brandSpotlightService.submit({
      shopId,
      dealLabel: payload.dealLabel,
      subtitle: payload.subtitle,
      heroImageUrl: payload.heroImageUrl,
      bgColor: payload.bgColor,
      accentColor: payload.accentColor,
      ctaTarget: payload.ctaTarget,
      startAt: new Date(payload.startAt),
      endAt: new Date(payload.endAt),
    });
    res.status(201).json(created);
  }

  async listForShop(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const statusRaw = req.query.status as string | undefined;
    const status = statusRaw ? STATUSES.find((s) => s === statusRaw) : undefined;
    if (statusRaw && !status) {
      res.status(400).json({ error: 'Invalid status' });
      return;
    }
    const data = await brandSpotlightService.listForShop(shopId, { status });
    res.json({ data });
  }

  async cancel(req: Request, res: Response): Promise<void> {
    const shopId = req.shopId!;
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const result = await brandSpotlightService.cancelPending(shopId, id);
    if (result === 'not_found') {
      res.status(404).json({ error: 'Spotlight not found' });
      return;
    }
    if (result === 'not_pending') {
      res.status(409).json({ error: 'Only PENDING requests can be cancelled' });
      return;
    }
    res.status(204).send();
  }

  // ── Admin ────────────────────────────────────────────────────────

  async listAdmin(req: Request, res: Response): Promise<void> {
    const statusRaw = req.query.status as string | undefined;
    const status = statusRaw ? STATUSES.find((s) => s === statusRaw) : undefined;
    if (statusRaw && !status) {
      res.status(400).json({ error: 'Invalid status' });
      return;
    }
    const cursorRaw = req.query.cursor as string | undefined;
    const cursor = cursorRaw ? Number(cursorRaw) : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const result = await brandSpotlightService.listForAdmin({
      status,
      cursor: Number.isInteger(cursor) ? cursor : undefined,
      limit,
    });
    res.json(result);
  }

  async getAdmin(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const row = await brandSpotlightService.getByIdForAdmin(id);
    if (!row) {
      res.status(404).json({ error: 'Spotlight not found' });
      return;
    }
    res.json(row);
  }

  async approve(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const reviewerId = req.user!.sub;
    const row = await brandSpotlightService.approve(id, reviewerId);
    if (!row) {
      res.status(404).json({ error: 'Spotlight not found' });
      return;
    }
    res.json(row);
  }

  async reject(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const { reason } = rejectSchema.parse(req.body);
    const reviewerId = req.user!.sub;
    const row = await brandSpotlightService.reject(id, reviewerId, reason);
    if (!row) {
      res.status(404).json({ error: 'Spotlight not found' });
      return;
    }
    res.json(row);
  }

  // ── Public ───────────────────────────────────────────────────────

  async listActive(_req: Request, res: Response): Promise<void> {
    const data = await brandSpotlightService.listActive();
    res.json({ data });
  }
}

export const brandSpotlightController = new BrandSpotlightController();
