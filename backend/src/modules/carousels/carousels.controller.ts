import { Request, Response } from 'express';
import {
  BannerImageFit,
  BannerPlacement,
  BannerSlideMode,
  BannerTemplate,
} from '@prisma/client';
import { z } from 'zod';
import { carouselsService } from './carousels.service.js';
import { isValidCtaTarget } from '../../shared/cta-target.js';
import {
  imageTransformSchema,
  textBlocksSchema,
} from '../banners/freeform-payload.js';

const PLACEMENTS: [BannerPlacement, ...BannerPlacement[]] = [
  'HERO',
  'AD_STRIP',
  'PROMO',
  'CURATED_RAIL',
];

const TEMPLATES: [BannerTemplate, ...BannerTemplate[]] = [
  'CLASSIC',
  'MINIMAL',
  'IMAGE_ONLY',
  'SPLIT',
  'OVERLAY',
  'DEAL',
  'POSTER',
];

const IMAGE_FITS: [BannerImageFit, ...BannerImageFit[]] = ['COVER', 'CONTAIN'];

const SLIDE_MODES: [BannerSlideMode, ...BannerSlideMode[]] = [
  'TEMPLATED',
  'FREEFORM',
];

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

const createCarouselSchema = z.object({
  name: z.string().min(1).max(80),
  placement: z.enum(PLACEMENTS),
  isActive: z.boolean().optional(),
  startAt: z.string().datetime().nullable().optional(),
  endAt: z.string().datetime().nullable().optional(),
  sortOrder: z.number().int().min(0).max(10_000).optional(),
});

const updateCarouselSchema = createCarouselSchema
  .partial()
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
  });

const createSlideSchema = z.object({
  mode: z.enum(SLIDE_MODES).optional(),
  template: z.enum(TEMPLATES).optional(),
  imageFit: z.enum(IMAGE_FITS).optional(),
  textBlocks: textBlocksSchema.nullable().optional(),
  imageTransform: imageTransformSchema.nullable().optional(),
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
});

const updateSlideSchema = createSlideSchema
  .partial()
  .refine((d) => Object.keys(d).length > 0, {
    message: 'At least one field is required',
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

export class CarouselsController {
  // ── Merchant carousels ──────────────────────────────────────────────

  async listForShop(req: Request, res: Response): Promise<void> {
    const data = await carouselsService.listForShop(req.shopId!);
    res.json({ data });
  }

  async getOneForShop(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const row = await carouselsService.getByIdForShop(req.shopId!, id);
    if (!row) {
      res.status(404).json({ error: 'Carousel not found' });
      return;
    }
    res.json(row);
  }

  async createForShop(req: Request, res: Response): Promise<void> {
    const payload = createCarouselSchema.parse(req.body);
    const row = await carouselsService.createForShop(req.shopId!, {
      ...payload,
      startAt: toDate(payload.startAt),
      endAt: toDate(payload.endAt),
    });
    res.status(201).json(row);
  }

  async updateForShop(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateCarouselSchema.parse(req.body);
    const row = await carouselsService.updateForShop(req.shopId!, id, {
      ...payload,
      startAt: toDate(payload.startAt),
      endAt: toDate(payload.endAt),
    });
    if (!row) {
      res.status(404).json({ error: 'Carousel not found' });
      return;
    }
    res.json(row);
  }

  async deleteForShop(req: Request, res: Response): Promise<void> {
    const id = parseId(req.params.id);
    if (!id) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await carouselsService.deleteForShop(req.shopId!, id);
    if (!ok) {
      res.status(404).json({ error: 'Carousel not found' });
      return;
    }
    res.status(204).send();
  }

  // ── Slides (nested under /me/carousels/:carouselId/slides) ──────────

  async listSlides(req: Request, res: Response): Promise<void> {
    const carouselId = parseId(req.params.carouselId);
    if (!carouselId) {
      res.status(400).json({ error: 'Invalid carousel id' });
      return;
    }
    const rows = await carouselsService.listSlides(req.shopId!, carouselId);
    if (rows === null) {
      res.status(404).json({ error: 'Carousel not found' });
      return;
    }
    res.json({ data: rows });
  }

  async getSlide(req: Request, res: Response): Promise<void> {
    const carouselId = parseId(req.params.carouselId);
    const slideId = parseId(req.params.slideId);
    if (!carouselId || !slideId) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const row = await carouselsService.getSlide(
      req.shopId!,
      carouselId,
      slideId,
    );
    if (!row) {
      res.status(404).json({ error: 'Slide not found' });
      return;
    }
    res.json(row);
  }

  async createSlide(req: Request, res: Response): Promise<void> {
    const carouselId = parseId(req.params.carouselId);
    if (!carouselId) {
      res.status(400).json({ error: 'Invalid carousel id' });
      return;
    }
    const payload = createSlideSchema.parse(req.body);
    const row = await carouselsService.createSlide(
      req.shopId!,
      carouselId,
      {
        ...payload,
        startAt: toDate(payload.startAt),
        endAt: toDate(payload.endAt),
      },
    );
    if (!row) {
      res.status(404).json({ error: 'Carousel not found' });
      return;
    }
    res.status(201).json(row);
  }

  async updateSlide(req: Request, res: Response): Promise<void> {
    const carouselId = parseId(req.params.carouselId);
    const slideId = parseId(req.params.slideId);
    if (!carouselId || !slideId) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const payload = updateSlideSchema.parse(req.body);
    const row = await carouselsService.updateSlide(
      req.shopId!,
      carouselId,
      slideId,
      {
        ...payload,
        startAt: toDate(payload.startAt),
        endAt: toDate(payload.endAt),
      },
    );
    if (!row) {
      res.status(404).json({ error: 'Slide not found' });
      return;
    }
    res.json(row);
  }

  async deleteSlide(req: Request, res: Response): Promise<void> {
    const carouselId = parseId(req.params.carouselId);
    const slideId = parseId(req.params.slideId);
    if (!carouselId || !slideId) {
      res.status(400).json({ error: 'Invalid id' });
      return;
    }
    const ok = await carouselsService.deleteSlide(
      req.shopId!,
      carouselId,
      slideId,
    );
    if (!ok) {
      res.status(404).json({ error: 'Slide not found' });
      return;
    }
    res.status(204).send();
  }

  // ── Admin (cross-shop) ──────────────────────────────────────────────

  async listAdmin(req: Request, res: Response): Promise<void> {
    const placementRaw = req.query.placement as string | undefined;
    const placement = placementRaw
      ? PLACEMENTS.find((p) => p === placementRaw)
      : undefined;
    const shopRaw = req.query.shopId as string | undefined;
    let shopId: number | null | undefined = undefined;
    if (shopRaw !== undefined) {
      if (shopRaw === '' || shopRaw === 'null') {
        // Caller explicitly asked for platform-curated carousels (the ones
        // with no owning shop). Distinct from "not filtering at all".
        shopId = null;
      } else {
        const parsed = Number(shopRaw);
        if (!Number.isInteger(parsed) || parsed <= 0) {
          res.status(400).json({ error: 'Invalid shopId' });
          return;
        }
        shopId = parsed;
      }
    }
    const cursorRaw = req.query.cursor as string | undefined;
    const cursor = cursorRaw ? Number(cursorRaw) : undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const result = await carouselsService.listForAdmin({
      placement,
      shopId,
      cursor: Number.isInteger(cursor) ? cursor : undefined,
      limit,
    });
    res.json(result);
  }
}

export const carouselsController = new CarouselsController();
