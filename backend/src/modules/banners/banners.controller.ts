import { Request, Response } from 'express';
import { BannerPlacement } from '@prisma/client';
import { z } from 'zod';
import { bannersService } from './banners.service.js';
import { isValidCtaTarget } from '../../shared/cta-target.js';

const PLACEMENTS: [BannerPlacement, ...BannerPlacement[]] = [
  'HERO',
  'AD_STRIP',
  'PROMO',
  'CURATED_RAIL',
];

// 7-char `#RRGGBB` or 9-char `#RRGGBBAA` so the merchant UI doesn't
// have to handle named colors / rgb(). Keeps the serialiser happy too.
const hexColor = z
  .string()
  .regex(/^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/, 'Must be hex like #RRGGBB');

const ctaTargetSchema = z
  .string()
  .max(2048)
  .refine(isValidCtaTarget, 'Invalid CTA target');

const imageRef = z
  .string()
  .min(1)
  .max(2048)
  .refine((v) => /^https?:\/\//i.test(v) || v.startsWith('/'), {
    message: 'Must be an http(s) URL or a server-relative path',
  });

const createBannerSchema = z.object({
  placement: z.enum(PLACEMENTS),
  title: z.string().min(1).max(120),
  subtitle: z.string().max(240).nullable().optional(),
  eyebrow: z.string().max(60).nullable().optional(),
  ctaText: z.string().max(40).nullable().optional(),
  ctaTarget: ctaTargetSchema.nullable().optional(),
  brandLabel: z.string().max(40).nullable().optional(),
  imageUrl: imageRef,
  bgColor: hexColor,
  accentColor: hexColor.nullable().optional(),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
  startAt: z.string().datetime().nullable().optional(),
  endAt: z.string().datetime().nullable().optional(),
  isActive: z.boolean().optional(),
  sponsorShopId: z.number().int().positive().nullable().optional(),
});

const updateBannerSchema = createBannerSchema
  .partial()
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

// Merchant-side schemas — same shape as the admin ones but with
// `sponsorShopId` dropped (the service stamps it from req.shopId).
const merchantCreateBannerSchema = createBannerSchema.omit({
  sponsorShopId: true,
});
const merchantUpdateBannerSchema = merchantCreateBannerSchema
  .partial()
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

// Replace-the-list payload for /me/banners/:id/products. Empty `items`
// is allowed — that clears the slide's linked products.
const replaceBannerProductsSchema = z.object({
  items: z
    .array(
      z.object({
        productId: z.number().int().positive(),
        discountPct: z.number().int().min(0).max(90).optional(),
        position: z.number().int().min(0).max(10_000).optional(),
      }),
    )
    .max(60),
});

function parseId(raw: string): number | null {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
}

function toDate(v: string | null | undefined): Date | null | undefined {
  if (v === undefined) return undefined;
  if (v === null) return null;
  return new Date(v);
}

export class BannersController {
  /// GET /banners?placement=HERO — public read of the live placement.
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

  // ── Admin endpoints (requirePlatformAdmin) ───────────────────────

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

  // ── Merchant endpoints (OWNER + resolveShop) ─────────────────────
  //
  // Owners create their own hero-carousel slides; every endpoint scopes
  // through req.shopId so a merchant can never read or mutate another
  // shop's banner by guessing an id. `sponsorShopId` is force-set by
  // the service to the caller's shop — the payload field is rejected.

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
    const payload = merchantCreateBannerSchema.parse(req.body);
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
    const payload = merchantUpdateBannerSchema.parse(req.body);
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

  // ── Per-slide linked products (merchant + public) ────────────────

  async listProductsForShopBanner(
    req: Request,
    res: Response,
  ): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const rows = await bannersService.listProductsForShopBanner(
      req.shopId!,
      id,
    );
    if (rows === null) {
      res.status(404).json({ error: 'Banner not found' });
      return;
    }
    res.json({ data: rows });
  }

  async replaceProductsForShopBanner(
    req: Request,
    res: Response,
  ): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = replaceBannerProductsSchema.parse(req.body);
    try {
      const rows = await bannersService.replaceProductsForShopBanner(
        req.shopId!,
        id,
        payload.items.map((it, idx) => ({
          productId: it.productId,
          discountPct: it.discountPct ?? 0,
          // Default position to the array index so the merchant can
          // skip filling it and still get a stable list order.
          position: it.position ?? idx,
        })),
      );
      if (rows === null) {
        res.status(404).json({ error: 'Banner not found' });
        return;
      }
      res.json({ data: rows });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Save failed';
      // Cross-shop product attempt is a 400 (client mistake), not 500.
      if (message.includes('does not belong to this shop')) {
        res.status(400).json({ error: message });
        return;
      }
      throw err;
    }
  }

  /// GET /banners/:id/slide — public. Returns the live banner + its
  /// linked products with computed sale prices. 404 if the banner is
  /// off, scheduled out, or doesn't exist (customer never lands here
  /// for an invisible slide).
  async getPublicSlide(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const slide = await bannersService.getPublicSlide(id);
    if (!slide) {
      res.status(404).json({ error: 'Slide not found' });
      return;
    }
    res.json(slide);
  }
}

export const bannersController = new BannersController();
