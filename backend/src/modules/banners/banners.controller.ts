import { Request, Response } from 'express';
import { zPublicId } from '../../shared/ids/zPublicId.js';
import { decodeId } from '../../shared/ids/publicId.js';
import { BannerPlacement } from '@prisma/client';
import { z } from 'zod';
import { bannersService } from './banners.service.js';
import {
  BANNER_LINK_HELP,
  formatBannerLink,
  parseBannerLink,
} from './banner-link.js';

const PLACEMENTS: [BannerPlacement, ...BannerPlacement[]] = [
  'HERO',
  'AD_STRIP',
  'PROMO',
  'CURATED_RAIL',
];

const imageRef = z
  .string()
  .min(1)
  .max(2048)
  .refine((v) => /^https?:\/\//i.test(v) || v.startsWith('/'), {
    message: 'Must be an http(s) URL or a server-relative path',
  });

const linkRef = z
  .string()
  .max(2048)
  .refine((v) => parseBannerLink(v) !== null, { message: BANNER_LINK_HELP })
  .transform((v) => formatBannerLink(parseBannerLink(v)!));

const createBannerSchema = z.object({
  placement: z.enum(PLACEMENTS),
  imageUrl: imageRef,
  linkUrl: linkRef.nullable().optional(),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
  startAt: z.string().datetime().nullable().optional(),
  endAt: z.string().datetime().nullable().optional(),
  isActive: z.boolean().optional(),
});

const updateBannerSchema = createBannerSchema
  .partial()
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

const replaceBannerProductsSchema = z.object({
  items: z
    .array(
      z.object({
        productId: zPublicId,
        discountType: z.enum(['PERCENT', 'AMOUNT']).optional(),
        discountValue: z.number().min(0).max(1_000_000).optional(),
        discountPct: z.number().int().min(0).max(90).optional(),
        position: z.number().int().min(0).max(10_000).optional(),
      }),
    )
    .max(60)
    .refine((items) => new Set(items.map((i) => i.productId)).size === items.length, {
      message: 'A product can only be pinned to a banner once',
    }),
});

function parseId(raw: string): number | null {
  return decodeId(raw);
}

function toDate(v: string | null | undefined): Date | null | undefined {
  if (v === undefined) return undefined;
  if (v === null) return null;
  return new Date(v);
}

export class BannersController {
  async listPublic(req: Request, res: Response): Promise<void> {
    const placementRaw = (req.query.placement as string | undefined) ?? '';
    const placement = PLACEMENTS.find((p) => p === placementRaw);
    if (!placement) {
      res.status(400).json({ error: 'Invalid or missing placement' });
      return;
    }
    const data = await bannersService.getActiveByPlacement(placement);
    res.json({ data });
  }

  async listAdmin(req: Request, res: Response): Promise<void> {
    const placementRaw = req.query.placement as string | undefined;
    const placement = placementRaw
      ? PLACEMENTS.find((p) => p === placementRaw)
      : undefined;
    const cursorRaw = req.query.cursor as string | undefined;
    const cursor = cursorRaw ? Number(cursorRaw) : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const result = await bannersService.listForAdmin({
      placement,
      cursor: Number.isInteger(cursor) ? cursor : undefined,
      limit,
    });
    res.json(result);
  }

  async getOne(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const banner = await bannersService.getById(id);
    if (!banner) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.json(banner);
  }

  async create(req: Request, res: Response): Promise<void> {
    const payload = createBannerSchema.parse(req.body);
    const banner = await bannersService.create({
      ...payload,
      startAt: toDate(payload.startAt),
      endAt: toDate(payload.endAt),
    });
    res.status(201).json(banner);
  }

  async update(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateBannerSchema.parse(req.body);
    const banner = await bannersService.update(id, {
      ...payload,
      startAt: toDate(payload.startAt),
      endAt: toDate(payload.endAt),
    });
    if (!banner) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.json(banner);
  }

  async delete(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await bannersService.delete(id);
    if (!ok) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.status(204).send();
  }

  async listForShop(req: Request, res: Response): Promise<void> {
    const data = await bannersService.listForShop(req.shopId!);
    res.json({ data });
  }

  async getOneForShop(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const banner = await bannersService.getByIdForShop(req.shopId!, id);
    if (!banner) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.json(banner);
  }

  async createForShop(req: Request, res: Response): Promise<void> {
    const payload = createBannerSchema.parse(req.body);
    const banner = await bannersService.createForShop(req.shopId!, {
      ...payload,
      startAt: toDate(payload.startAt),
      endAt: toDate(payload.endAt),
    });
    res.status(201).json(banner);
  }

  async updateForShop(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateBannerSchema.parse(req.body);
    const banner = await bannersService.updateForShop(req.shopId!, id, {
      ...payload,
      startAt: toDate(payload.startAt),
      endAt: toDate(payload.endAt),
    });
    if (!banner) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.json(banner);
  }

  async deleteForShop(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await bannersService.deleteForShop(req.shopId!, id);
    if (!ok) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.status(204).send();
  }

  async listProductsForShopBanner(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const rows = await bannersService.listProductsForShopBanner(req.shopId!, id);
    if (rows === null) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.json({ data: rows });
  }

  async replaceProductsForShopBanner(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = replaceBannerProductsSchema.parse(req.body);
    const rows = await bannersService.replaceProductsForShopBanner(
      req.shopId!,
      id,
      payload.items.map((it, idx) => {
        const hasTyped = it.discountType !== undefined || it.discountValue !== undefined;
        const type = it.discountType ?? 'PERCENT';
        const rawValue = hasTyped ? (it.discountValue ?? 0) : (it.discountPct ?? 0);
        return {
          productId: it.productId,
          discountType: type,
          discountValueRaw: rawValue,
          position: it.position ?? idx,
        };
      }),
    );
    if (rows === null) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.json({ data: rows });
  }

  async getPublicDetail(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const detail = await bannersService.getPublicBannerWithProducts(id);
    if (!detail) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.json(detail);
  }
}

export const bannersController = new BannersController();
