import { Request, Response } from 'express';
import { z } from 'zod';
import { shopService } from './shop.service.js';

// Image fields accept either an absolute http(s) URL or a server-relative
// path. Uploaded variants come back as `/images/<uuid>-md.webp`, so the
// strict `z.string().url()` we shipped initially rejected every save the
// merchant made right after uploading a logo / banner.
const imageRef = z
  .string()
  .min(1)
  .max(2048)
  .refine((v) => /^https?:\/\//i.test(v) || v.startsWith('/'), {
    message: 'Must be an http(s) URL or a server-relative path',
  });

const updateShopSchema = z
  .object({
    name: z.string().min(2).max(80).optional(),
    tagline: z.string().max(140).nullable().optional(),
    logoUrl: imageRef.nullable().optional(),
    bannerUrl: imageRef.nullable().optional(),
    // Public-facing policy text and location. Caps borrowed from
    // common marketplace usage — 4 KB is more than enough for a
    // returns blurb without enabling a wall-of-text customer scroll.
    locationCity: z.string().trim().max(120).nullable().optional(),
    locationState: z.string().trim().max(120).nullable().optional(),
    returnPolicy: z.string().trim().max(4096).nullable().optional(),
    shippingPolicy: z.string().trim().max(4096).nullable().optional(),
    refundPolicy: z.string().trim().max(4096).nullable().optional(),
    vacationMode: z.boolean().optional(),
    vacationMessage: z.string().trim().max(280).nullable().optional(),
    // Operating hours map. Keys are 3-letter lowercase day codes
    // (mon, tue, …, sun); values are [open, close] tuples in HH:MM.
    // Missing days mean closed.
    operatingHours: z
      .record(
        z.enum(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']),
        z.tuple([
          z.string().regex(/^\d{2}:\d{2}$/),
          z.string().regex(/^\d{2}:\d{2}$/),
        ]),
      )
      .nullable()
      .optional(),
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

const setVerifiedSchema = z.object({
  isVerified: z.boolean(),
});

const setPublishedSchema = z.object({
  isPublished: z.boolean(),
});

export class ShopController {
  async getMine(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const shop = await shopService.getMyShop(userId);
    if (!shop) {
      res.status(404).json({ error: 'Shop not found' });
      return;
    }
    res.json(shop);
  }

  async updateMine(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const payload = updateShopSchema.parse(req.body);
    const shop = await shopService.updateMyShop(userId, payload);
    res.json(shop);
  }

  async setPublished(req: Request, res: Response): Promise<void> {
    const userId = req.user!.sub;
    const { isPublished } = setPublishedSchema.parse(req.body);
    const shop = await shopService.setPublished(userId, isPublished);
    res.json(shop);
  }

  async listAdmin(req: Request, res: Response): Promise<void> {
    const search = (req.query.search as string | undefined)?.trim() || '';
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const data = await shopService.listForAdmin({ search, limit });
    res.json({ data });
  }

  async setVerified(req: Request, res: Response): Promise<void> {
    const shopIdRaw = Number(req.params.id);
    if (!Number.isInteger(shopIdRaw) || shopIdRaw <= 0) {
      res.status(400).json({ error: 'Invalid shop id' });
      return;
    }
    const { isVerified } = setVerifiedSchema.parse(req.body);
    const shop = await shopService.setVerified(shopIdRaw, isVerified);
    if (!shop) {
      res.status(404).json({ error: 'Shop not found' });
      return;
    }
    res.json(shop);
  }

  async getPublicBySlug(req: Request, res: Response): Promise<void> {
    const slug = String(req.params.slug || '').toLowerCase();
    if (!/^[a-z0-9-]{1,80}$/.test(slug)) {
      res.status(400).json({ error: 'Invalid slug' });
      return;
    }
    const shop = await shopService.getPublicShopBySlug(slug);
    if (!shop) {
      res.status(404).json({ error: 'Shop not found' });
      return;
    }
    res.json(shop);
  }
}

export const shopController = new ShopController();
