import { Request, Response } from 'express';
import { z } from 'zod';
import { decodeId } from '../../shared/ids/publicId.js';
import { resolveLocale } from './hsn.copy.js';
import { hsnService } from './hsn.service.js';
import { classifyService } from './classify.service.js';

const searchSchema = z.object({
  q: z.string().max(160).optional(),
  kind: z.enum(['GOODS', 'SERVICES']).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional(),
  locale: z.string().max(10).optional(),
  asOf: z.coerce.date().optional(),
});

const resolveSchema = z.object({
  code: z.string().min(1).max(20),
  price: z.coerce.number().min(0).optional(),
  locale: z.string().max(10).optional(),
  asOf: z.coerce.date().optional(),
});

const suggestSchema = z.object({
  name: z.string().min(1).max(300),
  locale: z.string().max(10).optional(),
  limit: z.coerce.number().int().min(1).max(20).optional(),
});

const shortcutSchema = z.object({
  label: z.string().min(1).max(120),
  code: z.string().min(1).max(20),
});

const resolveGapSchema = z.object({
  term: z.string().min(1).max(300),
  code: z.string().min(1).max(20),
});

const overrideSchema = z.object({
  code: z.string().min(1).max(20),
  gstRate: z.number().min(0).max(100),
  cessRate: z.number().min(0).max(500).optional(),
  reason: z.string().min(3).max(500),
  effectiveFrom: z.coerce.date().optional(),
});

function callerShopId(req: Request): number | undefined {
  return req.shopId ?? req.user?.shopId ?? undefined;
}

function callerLocale(req: Request, explicit?: string) {
  return resolveLocale(explicit ?? req.headers['accept-language']?.split(',')[0]);
}

export class HsnController {
  async search(req: Request, res: Response): Promise<void> {
    const parsed = searchSchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid query', details: parsed.error.flatten() });
      return;
    }
    const results = await hsnService.search({
      query: parsed.data.q ?? '',
      shopId: callerShopId(req),
      locale: callerLocale(req, parsed.data.locale),
      kind: parsed.data.kind,
      limit: parsed.data.limit,
      asOf: parsed.data.asOf,
    });
    res.json({ results });
  }

  async resolve(req: Request, res: Response): Promise<void> {
    const parsed = resolveSchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid query', details: parsed.error.flatten() });
      return;
    }
    const locale = callerLocale(req, parsed.data.locale);
    const outcome = await hsnService.resolveOutcome({
      code: parsed.data.code,
      shopId: callerShopId(req),
      price: parsed.data.price,
      asOf: parsed.data.asOf,
    });
    if (outcome.status !== 'RESOLVED') {
      res.status(404).json({
        error:
          outcome.status === 'UNRATED' && outcome.reason === 'CONDITIONAL'
            ? 'This code has no single GST rate — it depends on the goods'
            : 'No GST rate on file for this HSN/SAC code',
        ...(outcome.status === 'UNRATED'
          ? { code: outcome.code, reason: outcome.reason, note: outcome.note }
          : {}),
      });
      return;
    }
    const hit = outcome.rate;
    const breadcrumb = await hsnService.breadcrumb(hit.code, locale, parsed.data.asOf);
    res.json({ ...hit, breadcrumb });
  }

  async tree(req: Request, res: Response): Promise<void> {
    const code = typeof req.query.code === 'string' ? req.query.code : '';
    if (!code) {
      res.status(400).json({ error: 'Missing code' });
      return;
    }
    const nodes = await hsnService.breadcrumb(code, callerLocale(req));
    res.json({ nodes });
  }

  async suggest(req: Request, res: Response): Promise<void> {
    const parsed = suggestSchema.safeParse(req.query);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid query', details: parsed.error.flatten() });
      return;
    }
    const suggestions = await classifyService.suggestForName({
      name: parsed.data.name,
      shopId: callerShopId(req),
      locale: callerLocale(req, parsed.data.locale),
      limit: parsed.data.limit,
    });
    res.json(suggestions);
  }

  async gaps(req: Request, res: Response): Promise<void> {
    const limit = Number(req.query.limit);
    const gaps = await classifyService.outstandingGaps(
      Number.isFinite(limit) ? limit : undefined,
    );
    res.json({ gaps });
  }

  async resolveGap(req: Request, res: Response): Promise<void> {
    const parsed = resolveGapSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
      return;
    }
    const updated = await classifyService.resolveGap(parsed.data.term, parsed.data.code);
    res.json({ updated });
  }

  async listShortcuts(req: Request, res: Response): Promise<void> {
    const shortcuts = await hsnService.listShortcuts(req.shopId!, callerLocale(req));
    res.json({ shortcuts });
  }

  async saveShortcut(req: Request, res: Response): Promise<void> {
    const parsed = shortcutSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
      return;
    }
    const rate = await hsnService.resolveRate({
      code: parsed.data.code,
      shopId: req.shopId!,
    });
    if (!rate) {
      res.status(422).json({ error: 'That code has no GST rate on file' });
      return;
    }
    const saved = await hsnService.saveShortcut(req.shopId!, parsed.data.label, parsed.data.code);
    if (!saved) {
      res.status(400).json({ error: 'Invalid label or code' });
      return;
    }
    res.status(201).json(saved);
  }

  async deleteShortcut(req: Request, res: Response): Promise<void> {
    const id = decodeId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await hsnService.deleteShortcut(req.shopId!, id);
    if (!ok) {
      res.status(404).json({ error: 'Shortcut not found' });
      return;
    }
    res.status(204).send();
  }

  async listOverrides(req: Request, res: Response): Promise<void> {
    const overrides = await hsnService.listOverrides(req.shopId!);
    res.json({ overrides });
  }

  async createOverride(req: Request, res: Response): Promise<void> {
    const parsed = overrideSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'Invalid payload', details: parsed.error.flatten() });
      return;
    }
    const created = await hsnService.createOverride({
      shopId: req.shopId!,
      ...parsed.data,
      createdByUserId: req.user?.sub,
    });
    if (!created) {
      res.status(400).json({ error: 'Invalid code' });
      return;
    }
    res.status(201).json(created);
  }

  async deleteOverride(req: Request, res: Response): Promise<void> {
    const id = decodeId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await hsnService.deleteOverride(req.shopId!, id);
    if (!ok) {
      res.status(404).json({ error: 'Override not found' });
      return;
    }
    res.status(204).send();
  }
}

export const hsnController = new HsnController();
