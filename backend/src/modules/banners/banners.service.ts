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

const ACTIVE_CACHE_TTL_SECONDS = 60;

function activeCacheKey(placement: BannerPlacement): string {
  return `banners:active:${placement}`;
}

const publicBannerSelect = {
  id: true,
  placement: true,
  /// Phase 1 — wire through. Customer renderer branches on `mode` and
  /// then on either `template` (TEMPLATED) or textBlocks + imageTransform
  /// (FREEFORM). Without these, the client always falls back to CLASSIC.
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
  sponsorShopId: true,
  carouselId: true,
} as const;

const adminBannerSelect = {
  ...publicBannerSelect,
  startAt: true,
  endAt: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
} as const;

export interface CreateBannerInput {
  placement: BannerPlacement;
  /// Phase 1 — discriminator. Defaults to TEMPLATED.
  mode?: BannerSlideMode;
  template?: BannerTemplate;
  imageFit?: BannerImageFit;
  /// Validated + bounded by the controller's zod schema. Service stores
  /// as-is; the customer renderer parses these into typed widgets.
  textBlocks?: Prisma.InputJsonValue | null;
  imageTransform?: Prisma.InputJsonValue | null;
  carouselId?: number | null;
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
  sponsorShopId?: number | null;
}

export interface UpdateBannerInput extends Partial<CreateBannerInput> {}

export class BannersService {
  /// Public read — only banners that are active AND inside their
  /// scheduling window. Cached in Redis for 60s so home-feed reads
  /// don't hit Postgres on every request. Cache key is per placement,
  /// invalidated by any banner write.
  async getActiveByPlacement(placement: BannerPlacement) {
    if (redisAvailable()) {
      try {
        const cached = await getRedis().get(activeCacheKey(placement));
        if (cached) return JSON.parse(cached) as Array<Record<string, unknown>>;
      } catch (err) {
        // Cache reads are best-effort; fall through to DB on any error.
        logger.warn({ err: (err as Error).message }, 'banner cache read failed');
      }
    }

    const now = new Date();
    // Slide-level AND carousel-level gating: a slide is visible only if
    // its own isActive + schedule pass AND its carousel (when present)
    // is also active + in-window. carouselId IS NULL is grandfathered
    // through for pre-migration legacy rows that haven't been backfilled
    // yet (the Phase 1 migration backfills them, but a fresh
    // schema-only deploy might race; this keeps reads correct in that
    // window).
    const rows = await prisma.banner.findMany({
      where: {
        placement,
        isActive: true,
        AND: [
          { OR: [{ startAt: null }, { startAt: { lte: now } }] },
          { OR: [{ endAt: null }, { endAt: { gte: now } }] },
          {
            OR: [
              { carouselId: null },
              {
                carousel: {
                  isActive: true,
                  AND: [
                    { OR: [{ startAt: null }, { startAt: { lte: now } }] },
                    { OR: [{ endAt: null }, { endAt: { gte: now } }] },
                  ],
                },
              },
            ],
          },
        ],
      },
      orderBy: [
        { carousel: { sortOrder: 'asc' } },
        { sortOrder: 'asc' },
        { id: 'asc' },
      ],
      select: publicBannerSelect,
    });

    if (redisAvailable()) {
      try {
        await getRedis().set(
          activeCacheKey(placement),
          JSON.stringify(rows),
          'EX',
          ACTIVE_CACHE_TTL_SECONDS,
        );
      } catch (err) {
        logger.warn({ err: (err as Error).message }, 'banner cache write failed');
      }
    }

    return rows;
  }

  /// Admin listing — returns ALL banners regardless of schedule + active
  /// state so the manager UI can show "Scheduled" / "Expired" / "Off".
  /// Optional placement filter; cursor pagination via the `cursor` arg.
  async listForAdmin(opts: {
    placement?: BannerPlacement;
    cursor?: number;
    limit?: number;
  }) {
    const limit = Math.min(100, Math.max(1, opts.limit ?? 50));
    const where: Prisma.BannerWhereInput = {};
    if (opts.placement) where.placement = opts.placement;
    const rows = await prisma.banner.findMany({
      where,
      orderBy: [{ placement: 'asc' }, { sortOrder: 'asc' }, { id: 'desc' }],
      ...(opts.cursor ? { cursor: { id: opts.cursor }, skip: 1 } : {}),
      take: limit + 1,
      select: adminBannerSelect,
    });
    const hasMore = rows.length > limit;
    const data = hasMore ? rows.slice(0, limit) : rows;
    return {
      data,
      nextCursor: hasMore ? data[data.length - 1].id : null,
    };
  }

  async getById(id: number) {
    return prisma.banner.findUnique({ where: { id }, select: adminBannerSelect });
  }

  async create(input: CreateBannerInput) {
    const row = await prisma.banner.create({
      data: {
        placement: input.placement,
        mode: input.mode ?? 'TEMPLATED',
        template: input.template ?? 'CLASSIC',
        imageFit: input.imageFit ?? 'COVER',
        textBlocks: input.textBlocks ?? Prisma.JsonNull,
        imageTransform: input.imageTransform ?? Prisma.JsonNull,
        carouselId: input.carouselId ?? null,
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
        sponsorShopId: input.sponsorShopId ?? null,
      },
      select: adminBannerSelect,
    });
    await this._invalidate(input.placement);
    return row;
  }

  async update(id: number, input: UpdateBannerInput) {
    // Read existing to know which placement bucket(s) to invalidate.
    const existing = await prisma.banner.findUnique({
      where: { id },
      select: { placement: true },
    });
    if (!existing) return null;

    const row = await prisma.banner.update({
      where: { id },
      data: {
        ...(input.placement !== undefined && { placement: input.placement }),
        ...(input.mode !== undefined && { mode: input.mode }),
        ...(input.template !== undefined && { template: input.template }),
        ...(input.imageFit !== undefined && { imageFit: input.imageFit }),
        ...(input.textBlocks !== undefined && {
          textBlocks: input.textBlocks ?? Prisma.JsonNull,
        }),
        ...(input.imageTransform !== undefined && {
          imageTransform: input.imageTransform ?? Prisma.JsonNull,
        }),
        ...(input.carouselId !== undefined && { carouselId: input.carouselId }),
        ...(input.title !== undefined && { title: input.title }),
        ...(input.subtitle !== undefined && { subtitle: input.subtitle }),
        ...(input.eyebrow !== undefined && { eyebrow: input.eyebrow }),
        ...(input.ctaText !== undefined && { ctaText: input.ctaText }),
        ...(input.ctaTarget !== undefined && { ctaTarget: input.ctaTarget }),
        ...(input.brandLabel !== undefined && { brandLabel: input.brandLabel }),
        ...(input.imageUrl !== undefined && { imageUrl: input.imageUrl }),
        ...(input.bgColor !== undefined && { bgColor: input.bgColor }),
        ...(input.accentColor !== undefined && { accentColor: input.accentColor }),
        ...(input.sortOrder !== undefined && { sortOrder: input.sortOrder }),
        ...(input.startAt !== undefined && { startAt: input.startAt }),
        ...(input.endAt !== undefined && { endAt: input.endAt }),
        ...(input.isActive !== undefined && { isActive: input.isActive }),
        ...(input.sponsorShopId !== undefined && { sponsorShopId: input.sponsorShopId }),
      },
      select: adminBannerSelect,
    });
    // Invalidate the placement we moved from AND the one we moved to.
    await this._invalidate(existing.placement);
    if (input.placement && input.placement !== existing.placement) {
      await this._invalidate(input.placement);
    }
    return row;
  }

  async delete(id: number) {
    const existing = await prisma.banner.findUnique({
      where: { id },
      select: { placement: true },
    });
    if (!existing) return false;
    await prisma.banner.delete({ where: { id } });
    await this._invalidate(existing.placement);
    return true;
  }

  /// Blow the per-placement cache. No-op when Redis is offline (the
  /// service degrades gracefully — see infra/redis.ts).
  private async _invalidate(placement: BannerPlacement): Promise<void> {
    if (!redisAvailable()) return;
    try {
      await getRedis().del(activeCacheKey(placement));
    } catch (err) {
      logger.warn({ err: (err as Error).message }, 'banner cache invalidate failed');
    }
  }

  // ── Merchant-scoped CRUD ─────────────────────────────────────────
  //
  // Every merchant owns an unbounded list of their own banners — they
  // see only rows where `sponsorShopId = <their shop>`. The platform
  // admin endpoints (above) still see and manage everything. Service
  // methods scope every query through shopId so id-probing across
  // shops returns 404, not somebody else's banner.

  async listForShop(shopId: number) {
    return prisma.banner.findMany({
      where: { sponsorShopId: shopId },
      orderBy: [{ placement: 'asc' }, { sortOrder: 'asc' }, { id: 'desc' }],
      select: adminBannerSelect,
    });
  }

  async getByIdForShop(shopId: number, id: number) {
    return prisma.banner.findFirst({
      where: { id, sponsorShopId: shopId },
      select: adminBannerSelect,
    });
  }

  async createForShop(
    shopId: number,
    input: Omit<CreateBannerInput, 'sponsorShopId'>,
  ) {
    return this.create({ ...input, sponsorShopId: shopId });
  }

  async updateForShop(shopId: number, id: number, input: UpdateBannerInput) {
    // Existence + ownership check in one query — keeps the merchant
    // from updating somebody else's banner even with a guessed id.
    const owned = await prisma.banner.findFirst({
      where: { id, sponsorShopId: shopId },
      select: { id: true },
    });
    if (!owned) return null;
    // Never let the merchant re-parent a banner onto another shop.
    const { sponsorShopId: _ignored, ...rest } = input;
    return this.update(id, rest);
  }

  async deleteForShop(shopId: number, id: number) {
    const owned = await prisma.banner.findFirst({
      where: { id, sponsorShopId: shopId },
      select: { id: true },
    });
    if (!owned) return false;
    return this.delete(id);
  }

  // ── Per-slide linked products (BannerProduct) ────────────────────
  //
  // Each merchant slide can pin a curated list of their own products
  // with a display-only percent-off. The slide-detail customer page
  // renders these with the discount baked in for visual merchandising;
  // the cart still charges the canonical sellingPrice — keeping this
  // surface from accidentally becoming a stealth price-override.

  /// Internal: list rows for a banner (merchant side — no published
  /// filter so a merchant sees their unpublished products too).
  async listProductsForShopBanner(shopId: number, bannerId: number) {
    const owned = await prisma.banner.findFirst({
      where: { id: bannerId, sponsorShopId: shopId },
      select: { id: true },
    });
    if (!owned) return null;
    return prisma.bannerProduct.findMany({
      where: { bannerId },
      orderBy: [{ position: 'asc' }, { id: 'asc' }],
      select: {
        id: true,
        productId: true,
        position: true,
        discountPct: true,
        product: {
          select: {
            id: true,
            name: true,
            sku: true,
            mrp: true,
            sellingPrice: true,
            isActive: true,
            isPublished: true,
            images: {
              select: { url: true, sortOrder: true },
              orderBy: { sortOrder: 'asc' },
              take: 1,
            },
          },
        },
      },
    });
  }

  /// Full-list replace. Validates that every productId belongs to the
  /// caller's shop, then rewrites the join table in a transaction so
  /// readers never see a half-applied list. Returns the new rows or
  /// null when the banner isn't owned by the shop.
  async replaceProductsForShopBanner(
    shopId: number,
    bannerId: number,
    items: Array<{ productId: number; discountPct: number; position: number }>,
  ) {
    const owned = await prisma.banner.findFirst({
      where: { id: bannerId, sponsorShopId: shopId },
      select: { id: true },
    });
    if (!owned) return null;

    if (items.length > 0) {
      // Cross-check every productId belongs to this shop — stops a
      // merchant from injecting another shop's listings into their slide.
      const productIds = items.map((i) => i.productId);
      const owns = await prisma.product.findMany({
        where: { id: { in: productIds }, shopId },
        select: { id: true },
      });
      const ownedSet = new Set(owns.map((p) => p.id));
      const stranger = productIds.find((id) => !ownedSet.has(id));
      if (stranger !== undefined) {
        throw new Error(
          `Product ${stranger} does not belong to this shop`,
        );
      }
    }

    await prisma.$transaction(async (tx) => {
      await tx.bannerProduct.deleteMany({ where: { bannerId } });
      if (items.length === 0) return;
      await tx.bannerProduct.createMany({
        data: items.map((i) => ({
          bannerId,
          productId: i.productId,
          discountPct: Math.max(0, Math.min(90, Math.round(i.discountPct))),
          position: i.position,
        })),
      });
    });

    return this.listProductsForShopBanner(shopId, bannerId);
  }

  /// Public slide-detail read. Returns the banner row + linked products
  /// with the computed sale price for each. Filters out unpublished /
  /// inactive products so the customer never lands on a 404 product
  /// detail from the slide. Returns null if the banner isn't visible
  /// (off, outside its schedule window, or doesn't exist).
  async getPublicSlide(id: number) {
    const now = new Date();
    const banner = await prisma.banner.findFirst({
      where: {
        id,
        isActive: true,
        AND: [
          { OR: [{ startAt: null }, { startAt: { lte: now } }] },
          { OR: [{ endAt: null }, { endAt: { gte: now } }] },
        ],
      },
      select: publicBannerSelect,
    });
    if (!banner) return null;

    const rows = await prisma.bannerProduct.findMany({
      where: {
        bannerId: id,
        product: { isActive: true, isPublished: true },
      },
      orderBy: [{ position: 'asc' }, { id: 'asc' }],
      select: {
        discountPct: true,
        position: true,
        product: {
          select: {
            id: true,
            name: true,
            mrp: true,
            sellingPrice: true,
            ratingAvg: true,
            ratingCount: true,
            shop: { select: { id: true, name: true, slug: true } },
            images: {
              select: { url: true, sortOrder: true },
              orderBy: { sortOrder: 'asc' },
            },
          },
        },
      },
    });

    const products = rows.map((r) => {
      const selling = Number(r.product.sellingPrice);
      const salePrice = +(selling * (1 - r.discountPct / 100)).toFixed(2);
      return {
        ...r.product,
        discountPct: r.discountPct,
        // Returned as a string to match Prisma's Decimal serialisation
        // shape — the customer mapper accepts both, but staying
        // consistent avoids special-case parsing.
        salePrice: salePrice.toFixed(2),
      };
    });

    return { banner, products };
  }
}

export const bannersService = new BannersService();
