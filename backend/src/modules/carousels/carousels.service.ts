import {
  BannerImageFit,
  BannerPlacement,
  BannerSlideMode,
  BannerTemplate,
  Prisma,
} from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';

/// Mirror of the bannerCache key shape in banners.service.ts. Kept in
/// sync by hand because pulling it across modules creates a circular
/// import; both writers must use the same string template so the
/// per-placement Redis blow-out works no matter which surface saved.
function bannerCacheKey(placement: BannerPlacement): string {
  return `banners:active:${placement}`;
}

async function invalidatePlacement(placement: BannerPlacement): Promise<void> {
  if (!redisAvailable()) return;
  try {
    await getRedis().del(bannerCacheKey(placement));
  } catch (err) {
    logger.warn(
      { err: (err as Error).message },
      'carousel cache invalidate failed',
    );
  }
}

const carouselSelect = {
  id: true,
  shopId: true,
  name: true,
  placement: true,
  isActive: true,
  startAt: true,
  endAt: true,
  sortOrder: true,
  createdAt: true,
  updatedAt: true,
} as const;

/// Slide-level select used by both merchant and admin reads. Mirrors
/// the columns wired through banners.service.ts adminBannerSelect so
/// the editor + customer renderer get identical payloads regardless of
/// which surface produced the row.
const slideSelect = {
  id: true,
  carouselId: true,
  placement: true,
  mode: true,
  template: true,
  imageFit: true,
  textBlocks: true,
  imageTransform: true,
  title: true,
  subtitle: true,
  eyebrow: true,
  ctaText: true,
  ctaTarget: true,
  brandLabel: true,
  imageUrl: true,
  bgColor: true,
  accentColor: true,
  sortOrder: true,
  startAt: true,
  endAt: true,
  isActive: true,
  sponsorShopId: true,
  createdAt: true,
  updatedAt: true,
} as const;

export interface CreateCarouselInput {
  name: string;
  placement: BannerPlacement;
  isActive?: boolean;
  startAt?: Date | null;
  endAt?: Date | null;
  sortOrder?: number;
}

export interface UpdateCarouselInput extends Partial<CreateCarouselInput> {}

export interface CreateSlideInput {
  mode?: BannerSlideMode;
  template?: BannerTemplate;
  imageFit?: BannerImageFit;
  textBlocks?: Prisma.InputJsonValue | null;
  imageTransform?: Prisma.InputJsonValue | null;
  title: string;
  subtitle?: string | null;
  eyebrow?: string | null;
  ctaText?: string | null;
  ctaTarget?: string | null;
  brandLabel?: string | null;
  imageUrl: string;
  bgColor: string;
  accentColor?: string | null;
  sortOrder?: number;
  startAt?: Date | null;
  endAt?: Date | null;
  isActive?: boolean;
}

export interface UpdateSlideInput extends Partial<CreateSlideInput> {}

export class CarouselsService {
  // ── Carousel CRUD ───────────────────────────────────────────────────

  async listForShop(shopId: number) {
    return prisma.carousel.findMany({
      where: { shopId },
      orderBy: [{ placement: 'asc' }, { sortOrder: 'asc' }, { id: 'desc' }],
      select: {
        ...carouselSelect,
        _count: { select: { slides: true } },
      },
    });
  }

  async getByIdForShop(shopId: number, id: number) {
    return prisma.carousel.findFirst({
      where: { id, shopId },
      select: carouselSelect,
    });
  }

  async createForShop(shopId: number, input: CreateCarouselInput) {
    const row = await prisma.carousel.create({
      data: {
        shopId,
        name: input.name.trim(),
        placement: input.placement,
        isActive: input.isActive ?? true,
        startAt: input.startAt ?? null,
        endAt: input.endAt ?? null,
        sortOrder: input.sortOrder ?? 0,
      },
      select: carouselSelect,
    });
    await invalidatePlacement(input.placement);
    return row;
  }

  async updateForShop(
    shopId: number,
    id: number,
    input: UpdateCarouselInput,
  ) {
    const existing = await prisma.carousel.findFirst({
      where: { id, shopId },
      select: { placement: true },
    });
    if (!existing) return null;

    const row = await prisma.carousel.update({
      where: { id },
      data: {
        ...(input.name !== undefined && { name: input.name.trim() }),
        ...(input.placement !== undefined && { placement: input.placement }),
        ...(input.isActive !== undefined && { isActive: input.isActive }),
        ...(input.startAt !== undefined && { startAt: input.startAt }),
        ...(input.endAt !== undefined && { endAt: input.endAt }),
        ...(input.sortOrder !== undefined && { sortOrder: input.sortOrder }),
      },
      select: carouselSelect,
    });
    // A carousel toggle or schedule change shifts the visible-slide set
    // for the placement; invalidate both the old and the new bucket.
    await invalidatePlacement(existing.placement);
    if (input.placement && input.placement !== existing.placement) {
      await invalidatePlacement(input.placement);
    }
    return row;
  }

  async deleteForShop(shopId: number, id: number): Promise<boolean> {
    const existing = await prisma.carousel.findFirst({
      where: { id, shopId },
      select: { placement: true },
    });
    if (!existing) return false;
    await prisma.carousel.delete({ where: { id } });
    await invalidatePlacement(existing.placement);
    return true;
  }

  // ── Slide CRUD (nested under a carousel the caller owns) ────────────

  /// Resolve a carousel id to its owner. Used by every slide endpoint
  /// before any DB mutation — if the carousel doesn't exist or belongs
  /// to another shop we return null and the controller maps that to 404.
  async assertCarouselOwnership(
    shopId: number,
    carouselId: number,
  ): Promise<{ placement: BannerPlacement } | null> {
    return prisma.carousel.findFirst({
      where: { id: carouselId, shopId },
      select: { placement: true },
    });
  }

  async listSlides(shopId: number, carouselId: number) {
    const owned = await this.assertCarouselOwnership(shopId, carouselId);
    if (!owned) return null;
    return prisma.banner.findMany({
      where: { carouselId },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
      select: slideSelect,
    });
  }

  async getSlide(shopId: number, carouselId: number, slideId: number) {
    const owned = await this.assertCarouselOwnership(shopId, carouselId);
    if (!owned) return null;
    return prisma.banner.findFirst({
      where: { id: slideId, carouselId },
      select: slideSelect,
    });
  }

  async createSlide(
    shopId: number,
    carouselId: number,
    input: CreateSlideInput,
  ) {
    const owned = await this.assertCarouselOwnership(shopId, carouselId);
    if (!owned) return null;
    const row = await prisma.banner.create({
      data: {
        // The carousel is the source of truth for placement + tenant. Slide
        // rows still carry placement on Banner so the public reader can
        // index on (placement, isActive, ...) without joining; we stamp it
        // from the carousel here so a misbehaving editor can't desync.
        carouselId,
        placement: owned.placement,
        sponsorShopId: shopId,
        mode: input.mode ?? 'TEMPLATED',
        template: input.template ?? 'CLASSIC',
        imageFit: input.imageFit ?? 'COVER',
        textBlocks: input.textBlocks ?? Prisma.JsonNull,
        imageTransform: input.imageTransform ?? Prisma.JsonNull,
        title: input.title,
        subtitle: input.subtitle ?? null,
        eyebrow: input.eyebrow ?? null,
        ctaText: input.ctaText ?? null,
        ctaTarget: input.ctaTarget ?? null,
        brandLabel: input.brandLabel ?? null,
        imageUrl: input.imageUrl,
        bgColor: input.bgColor,
        accentColor: input.accentColor ?? null,
        sortOrder: input.sortOrder ?? 0,
        startAt: input.startAt ?? null,
        endAt: input.endAt ?? null,
        isActive: input.isActive ?? true,
      },
      select: slideSelect,
    });
    await invalidatePlacement(owned.placement);
    return row;
  }

  async updateSlide(
    shopId: number,
    carouselId: number,
    slideId: number,
    input: UpdateSlideInput,
  ) {
    const owned = await this.assertCarouselOwnership(shopId, carouselId);
    if (!owned) return null;
    const existing = await prisma.banner.findFirst({
      where: { id: slideId, carouselId },
      select: { id: true },
    });
    if (!existing) return null;
    const row = await prisma.banner.update({
      where: { id: slideId },
      data: {
        ...(input.mode !== undefined && { mode: input.mode }),
        ...(input.template !== undefined && { template: input.template }),
        ...(input.imageFit !== undefined && { imageFit: input.imageFit }),
        ...(input.textBlocks !== undefined && {
          textBlocks: input.textBlocks ?? Prisma.JsonNull,
        }),
        ...(input.imageTransform !== undefined && {
          imageTransform: input.imageTransform ?? Prisma.JsonNull,
        }),
        ...(input.title !== undefined && { title: input.title }),
        ...(input.subtitle !== undefined && { subtitle: input.subtitle }),
        ...(input.eyebrow !== undefined && { eyebrow: input.eyebrow }),
        ...(input.ctaText !== undefined && { ctaText: input.ctaText }),
        ...(input.ctaTarget !== undefined && { ctaTarget: input.ctaTarget }),
        ...(input.brandLabel !== undefined && { brandLabel: input.brandLabel }),
        ...(input.imageUrl !== undefined && { imageUrl: input.imageUrl }),
        ...(input.bgColor !== undefined && { bgColor: input.bgColor }),
        ...(input.accentColor !== undefined && {
          accentColor: input.accentColor,
        }),
        ...(input.sortOrder !== undefined && { sortOrder: input.sortOrder }),
        ...(input.startAt !== undefined && { startAt: input.startAt }),
        ...(input.endAt !== undefined && { endAt: input.endAt }),
        ...(input.isActive !== undefined && { isActive: input.isActive }),
      },
      select: slideSelect,
    });
    await invalidatePlacement(owned.placement);
    return row;
  }

  async deleteSlide(
    shopId: number,
    carouselId: number,
    slideId: number,
  ): Promise<boolean> {
    const owned = await this.assertCarouselOwnership(shopId, carouselId);
    if (!owned) return false;
    const result = await prisma.banner.deleteMany({
      where: { id: slideId, carouselId },
    });
    if (result.count === 0) return false;
    await invalidatePlacement(owned.placement);
    return true;
  }

  // ── Admin variants (cross-shop) ─────────────────────────────────────

  async listForAdmin(opts: {
    placement?: BannerPlacement;
    shopId?: number | null;
    cursor?: number;
    limit?: number;
  }) {
    const limit = Math.min(100, Math.max(1, opts.limit ?? 50));
    const where: Prisma.CarouselWhereInput = {};
    if (opts.placement) where.placement = opts.placement;
    if (opts.shopId !== undefined) where.shopId = opts.shopId;
    const rows = await prisma.carousel.findMany({
      where,
      orderBy: [{ placement: 'asc' }, { sortOrder: 'asc' }, { id: 'desc' }],
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      take: limit + 1,
      select: { ...carouselSelect, _count: { select: { slides: true } } },
    });
    const hasMore = rows.length > limit;
    const data = hasMore ? rows.slice(0, limit) : rows;
    return {
      data,
      nextCursor: hasMore ? data[data.length - 1].id : null,
    };
  }
}

export const carouselsService = new CarouselsService();
