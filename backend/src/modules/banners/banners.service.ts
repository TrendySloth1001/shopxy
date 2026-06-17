import { BannerPlacement, Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { getRedis, redisAvailable } from '../../infra/redis.js';
import { logger } from '../../shared/logging/logger.js';
import { HttpError } from '../../shared/http/errorHandler.js';
import {
  clampDiscountValue,
  discountPerUnit,
  type DiscountType,
} from './promo-pricing.js';

const ACTIVE_CACHE_TTL_SECONDS = 60;

function activeCacheKey(placement: BannerPlacement): string {
  return `banners:active:${placement}`;
}

const publicBannerSelect = {
  id: true,
  placement: true,
  imageUrl: true,
  linkUrl: true,
  sortOrder: true,
  _count: { select: { products: true } },
} as const;

const ownerBannerSelect = {
  ...publicBannerSelect,
  shopId: true,
  startAt: true,
  endAt: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
} as const;

/** Flatten Prisma's `_count.products` into a plain `productCount` field. */
function withCount<T extends { _count: { products: number } }>(
  row: T,
): Omit<T, '_count'> & { productCount: number } {
  const { _count, ...rest } = row;
  return { ...rest, productCount: _count.products };
}

export interface CreateBannerInput {
  placement: BannerPlacement;
  imageUrl: string;
  linkUrl?: string | null;
  sortOrder?: number;
  startAt?: Date | null;
  endAt?: Date | null;
  isActive?: boolean;
  /// Owning shop. null = a platform-wide banner authored by an admin.
  shopId?: number | null;
}

export type UpdateBannerInput = Partial<CreateBannerInput>;

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
        logger.warn({ err: (err as Error).message }, 'banner cache read failed');
      }
    }

    const now = new Date();
    const rows = await prisma.banner.findMany({
      where: {
        placement,
        isActive: true,
        AND: [
          { OR: [{ startAt: null }, { startAt: { lte: now } }] },
          { OR: [{ endAt: null }, { endAt: { gte: now } }] },
        ],
      },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
      select: publicBannerSelect,
    });
    const mapped = rows.map(withCount);

    if (redisAvailable()) {
      try {
        await getRedis().set(
          activeCacheKey(placement),
          JSON.stringify(mapped),
          'EX',
          ACTIVE_CACHE_TTL_SECONDS,
        );
      } catch (err) {
        logger.warn({ err: (err as Error).message }, 'banner cache write failed');
      }
    }

    return mapped;
  }

  /// Admin listing — ALL banners regardless of schedule + active state
  /// so the manager UI can show "Scheduled" / "Expired" / "Off".
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
      select: ownerBannerSelect,
    });
    const hasMore = rows.length > limit;
    const data = hasMore ? rows.slice(0, limit) : rows;
    return {
      data: data.map(withCount),
      nextCursor: hasMore ? data[data.length - 1].id : null,
    };
  }

  async getById(id: number) {
    const row = await prisma.banner.findUnique({ where: { id }, select: ownerBannerSelect });
    return row ? withCount(row) : null;
  }

  async create(input: CreateBannerInput) {
    const row = await prisma.banner.create({
      data: this._writeData(input, true),
      select: ownerBannerSelect,
    });
    await this._invalidate(input.placement);
    return withCount(row);
  }

  async update(id: number, input: UpdateBannerInput) {
    const existing = await prisma.banner.findUnique({
      where: { id },
      select: { placement: true },
    });
    if (!existing) return null;
    const row = await prisma.banner.update({
      where: { id },
      data: this._writeData(input, false),
      select: ownerBannerSelect,
    });
    await this._invalidate(existing.placement);
    if (input.placement && input.placement !== existing.placement) {
      await this._invalidate(input.placement);
    }
    return withCount(row);
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

  // ── Merchant-scoped CRUD ─────────────────────────────────────────
  // Each merchant manages their own banners (shopId = their shop). All
  // queries scope through shopId so id-probing across shops returns 404.

  async listForShop(shopId: number) {
    const rows = await prisma.banner.findMany({
      where: { shopId },
      orderBy: [{ placement: 'asc' }, { sortOrder: 'asc' }, { id: 'desc' }],
      select: ownerBannerSelect,
    });
    return rows.map(withCount);
  }

  async getByIdForShop(shopId: number, id: number) {
    const row = await prisma.banner.findFirst({
      where: { id, shopId },
      select: ownerBannerSelect,
    });
    return row ? withCount(row) : null;
  }

  async createForShop(shopId: number, input: CreateBannerInput) {
    return this.create({ ...input, shopId });
  }

  async updateForShop(shopId: number, id: number, input: UpdateBannerInput) {
    const owned = await prisma.banner.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return null;
    // shopId can never be reassigned through the merchant path.
    const { shopId: _ignore, ...rest } = input;
    void _ignore;
    return this.update(id, rest);
  }

  async deleteForShop(shopId: number, id: number) {
    const owned = await prisma.banner.findFirst({
      where: { id, shopId },
      select: { id: true },
    });
    if (!owned) return false;
    return this.delete(id);
  }

  private _writeData(input: UpdateBannerInput, isCreate: boolean) {
    const data: Prisma.BannerUncheckedCreateInput | Prisma.BannerUncheckedUpdateInput = {};
    if (input.placement !== undefined) data.placement = input.placement;
    if (input.imageUrl !== undefined) data.imageUrl = input.imageUrl;
    if (input.linkUrl !== undefined) data.linkUrl = input.linkUrl;
    if (input.sortOrder !== undefined) data.sortOrder = input.sortOrder;
    if (input.startAt !== undefined) data.startAt = input.startAt;
    if (input.endAt !== undefined) data.endAt = input.endAt;
    if (input.isActive !== undefined) data.isActive = input.isActive;
    if (input.shopId !== undefined) data.shopId = input.shopId;
    if (isCreate) {
      data.sortOrder ??= 0;
      data.isActive ??= true;
      data.shopId ??= null;
    }
    return data as Prisma.BannerUncheckedCreateInput;
  }

  /// Blow the per-placement cache. No-op when Redis is offline.
  private async _invalidate(placement: BannerPlacement): Promise<void> {
    if (!redisAvailable()) return;
    try {
      await getRedis().del(activeCacheKey(placement));
    } catch (err) {
      logger.warn({ err: (err as Error).message }, 'banner cache invalidate failed');
    }
  }

  // ── Pinned products ──────────────────────────────────────────────
  // A merchant pins a curated list of their own products to a banner,
  // each with an optional promo discount. The customer banner-detail
  // page renders them with the discounted price; the discount also flows
  // into the order line + invoice via promo-pricing.resolveActiveProductPromos.

  /// Merchant read — the banner's pinned products (no published filter so
  /// the merchant sees their unpublished ones too). null if not owned.
  async listProductsForShopBanner(shopId: number, bannerId: number) {
    const owned = await prisma.banner.findFirst({
      where: { id: bannerId, shopId },
      select: { id: true },
    });
    if (!owned) return null;
    const rows = await prisma.bannerProduct.findMany({
      where: { bannerId },
      orderBy: [{ position: 'asc' }, { id: 'asc' }],
      select: {
        id: true,
        productId: true,
        position: true,
        discountType: true,
        discountValue: true,
        product: {
          select: {
            id: true,
            name: true,
            sku: true,
            mrp: true,
            sellingPrice: true,
            isActive: true,
            isPublished: true,
            images: { select: { url: true, sortOrder: true }, orderBy: { sortOrder: 'asc' }, take: 1 },
          },
        },
      },
    });
    return rows.map((r) => {
      const value = Number(r.discountValue);
      const selling = Number(r.product.sellingPrice);
      const perUnit = discountPerUnit(r.discountType, value, selling);
      return {
        ...r,
        discountValue: value,
        salePrice: +(selling - perUnit).toFixed(2),
        perUnitDiscount: perUnit,
      };
    });
  }

  /// Full-list replace, transactional. Validates every productId belongs
  /// to the caller's shop, clamps each discount, then rewrites the join.
  /// Returns the new rows, or null when the banner isn't owned.
  async replaceProductsForShopBanner(
    shopId: number,
    bannerId: number,
    items: Array<{
      productId: number;
      discountType: DiscountType;
      discountValueRaw: number;
      position: number;
    }>,
  ) {
    const owned = await prisma.banner.findFirst({
      where: { id: bannerId, shopId },
      select: { id: true },
    });
    if (!owned) return null;

    let priceByProduct = new Map<number, number>();
    if (items.length > 0) {
      const productIds = items.map((i) => i.productId);
      const owns = await prisma.product.findMany({
        where: { id: { in: productIds }, shopId },
        select: { id: true, sellingPrice: true },
      });
      const ownedSet = new Set(owns.map((p) => p.id));
      const stranger = productIds.find((id) => !ownedSet.has(id));
      if (stranger !== undefined) {
        throw new HttpError(
          400,
          'CROSS_SHOP_PRODUCT',
          `Product ${stranger} does not belong to this shop`,
          { productId: stranger },
        );
      }
      priceByProduct = new Map(owns.map((p) => [p.id, Number(p.sellingPrice)]));
    }

    await prisma.$transaction(async (tx) => {
      await tx.bannerProduct.deleteMany({ where: { bannerId } });
      if (items.length === 0) return;
      await tx.bannerProduct.createMany({
        data: items.map((i) => ({
          bannerId,
          productId: i.productId,
          discountType: i.discountType,
          discountValue: clampDiscountValue(
            i.discountType,
            i.discountValueRaw,
            priceByProduct.get(i.productId) ?? 0,
          ),
          position: i.position,
        })),
      });
    });

    return this.listProductsForShopBanner(shopId, bannerId);
  }

  /// Public banner detail — the visible banner + its pinned, published
  /// products with computed sale prices. null if the banner is off,
  /// outside its window, or doesn't exist.
  async getPublicBannerWithProducts(id: number) {
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
      where: { bannerId: id, product: { isActive: true, isPublished: true } },
      orderBy: [{ position: 'asc' }, { id: 'asc' }],
      select: {
        discountType: true,
        discountValue: true,
        product: {
          select: {
            id: true,
            name: true,
            mrp: true,
            sellingPrice: true,
            brand: true,
            ratingAvg: true,
            ratingCount: true,
            shop: { select: { id: true, name: true, slug: true } },
            images: { select: { url: true, sortOrder: true }, orderBy: { sortOrder: 'asc' } },
          },
        },
      },
    });

    const products = rows.map((r) => {
      const selling = Number(r.product.sellingPrice);
      const value = Number(r.discountValue);
      const perUnit = discountPerUnit(r.discountType, value, selling);
      const salePrice = +(selling - perUnit).toFixed(2);
      const derivedPct = selling > 0 ? Math.round((perUnit / selling) * 100) : 0;
      return {
        ...r.product,
        discountType: r.discountType,
        discountValue: value,
        discountPct: derivedPct,
        salePrice: salePrice.toFixed(2),
      };
    });

    return { banner: withCount(banner), products };
  }
}

export const bannersService = new BannersService();
