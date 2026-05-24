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
  })
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
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
