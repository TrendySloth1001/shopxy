import { Request, Response } from 'express';
import { z } from 'zod';
import { collectionsService } from './collections.service.js';
import { isValidCtaTarget } from '../../shared/cta-target.js';

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

const createSchema = z.object({
  title: z.string().min(1).max(120),
  slug: z.string().min(1).max(80).optional(),
  eyebrow: z.string().max(60).nullable().optional(),
  subtitle: z.string().max(240).nullable().optional(),
  ctaText: z.string().max(40).nullable().optional(),
  ctaTarget: ctaTargetSchema.nullable().optional(),
  coverImageUrl: imageRef.nullable().optional(),
  bgColor: hexColor.nullable().optional(),
  isPublished: z.boolean().optional(),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
});

const updateSchema = createSchema
  .partial()
  .refine((d) => Object.keys(d).length > 0, { message: 'At least one field is required' });

const itemsSchema = z.object({
  items: z
    .array(
      z.object({
        productId: z.number().int().positive(),
        position: z.number().int().min(0).max(10_000),
      }),
    )
    .max(200),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export class CollectionsController {
  // ── Admin ────────────────────────────────────────────────────────

  async listAdmin(req: Request, res: Response): Promise<void> {
    const cursorRaw = req.query.cursor as string | undefined;
    const cursor = cursorRaw ? Number(cursorRaw) : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const result = await collectionsService.listForAdmin({
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
    const row = await collectionsService.getByIdForAdmin(id);
    if (!row) {
      res.status(404).json({ error: 'Collection not found' });
      return;
    }
    res.json(row);
  }

  async create(req: Request, res: Response): Promise<void> {
    const payload = createSchema.parse(req.body);
    const created = await collectionsService.create(payload);
    res.status(201).json(created);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateSchema.parse(req.body);
    const row = await collectionsService.update(id, payload);
    if (!row) {
      res.status(404).json({ error: 'Collection not found' });
      return;
    }
    res.json(row);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await collectionsService.delete(id);
    if (!ok) {
      res.status(404).json({ error: 'Collection not found' });
      return;
    }
    res.status(204).send();
  }

  async replaceItems(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const { items } = itemsSchema.parse(req.body);
    try {
      const result = await collectionsService.replaceItems(id, items);
      if (!result) {
        res.status(404).json({ error: 'Collection not found' });
        return;
      }
      res.json({ data: result });
    } catch (e) {
      if ((e as Error & { code?: string }).code === 'INVALID_PRODUCTS') {
        res.status(400).json({ error: (e as Error).message });
        return;
      }
      throw e;
    }
  }

  async searchProducts(req: Request, res: Response): Promise<void> {
    const q = (req.query.q as string | undefined) ?? '';
    const data = await collectionsService.adminSearchProducts(q);
    res.json({ data });
  }

  // ── Public ───────────────────────────────────────────────────────

  async listPublic(_req: Request, res: Response): Promise<void> {
    const data = await collectionsService.listPublished();
    res.json({ data });
  }

  async getPublic(req: Request, res: Response): Promise<void> {
    const slug = req.params.slug;
    if (!slug || !/^[a-z0-9-]{1,80}$/.test(slug)) {
      res.status(400).json({ error: 'Invalid slug' });
      return;
    }
    const cursorRaw = req.query.cursor as string | undefined;
    const cursor = cursorRaw ? Number(cursorRaw) : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const row = await collectionsService.getBySlug(slug, {
      cursor: Number.isInteger(cursor) ? cursor : undefined,
      limit,
    });
    if (!row) {
      res.status(404).json({ error: 'Collection not found' });
      return;
    }
    res.json(row);
  }
}

export const collectionsController = new CollectionsController();
