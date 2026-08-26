import prisma from '../../infra/db/prisma.js';
import {
  getShuffledIds,
  getViewerOwnedProductIds,
  SEED_BUCKETS,
} from './endless-cache.service.js';
import { bannersService } from '../banners/banners.service.js';
import { trendingService } from '../trending/trending.service.js';
import { categoriesService } from '../categories/categories.service.js';

export class HomeService {
  async getFeed(): Promise<HomeFeedResponse> {
    const [
      heroBanners,
      adStripBanners,
      promoBanners,
      curatedRailBanners,
      trendingGlobal,
      categoryTree,
      newArrivals,
    ] = await Promise.all([
      this._safe(() => bannersService.getActiveByPlacement('HERO')),
      this._safe(() => bannersService.getActiveByPlacement('AD_STRIP')),
      this._safe(() => bannersService.getActiveByPlacement('PROMO')),
      this._safe(() => bannersService.getActiveByPlacement('CURATED_RAIL')),
      this._safe(() => trendingService.listTrending({ categoryId: null, take: 30 })),
      this._safe(() => categoriesService.getTree({ activeOnly: true })),
      this._safe(() => this._newArrivals(20)),
    ]);

    const trending = trendingGlobal.map((r) => ({
      score: Number(r.score),
      product: r.product,
    }));

    return {
      heroBanners,
      adStripBanners,
      promoBanners,
      curatedRailBanners,
      trending,
      newArrivals,
      categoryPucks: categoryTree
        .filter((c) => c.parentId == null)
        .slice(0, 12)
        .map((c) => ({
          id: c.id,
          slug: c.slug,
          name: c.name,
          imageUrl: c.imageUrl,
          iconName: c.iconName,
        })),
    };
  }

  private async _newArrivals(take: number) {
    return prisma.product.findMany({
      where: { isActive: true, isPublished: true },
      orderBy: { createdAt: 'desc' },
      take,
      select: {
        id: true,
        name: true,
        mrp: true,
        sellingPrice: true,
        brand: true,
        ratingAvg: true,
        ratingCount: true,
        images: {
          select: { url: true, sortOrder: true },
          orderBy: { sortOrder: 'asc' as const },
          take: 1,
        },
        shop: { select: { id: true, name: true, slug: true } },
      },
    });
  }

  private async _safe<T>(fn: () => Promise<T[]>): Promise<T[]> {
    try {
      return await fn();
    } catch {
      return [];
    }
  }

  async getCategoryRail(categoryId: number, take = 10) {
    const rows = await trendingService.listTrending({ categoryId, take });
    return rows.map((r) => ({ score: Number(r.score), product: r.product }));
  }

  async getEndlessPage(opts: { seed: number; page: number; limit: number; viewerUserId?: number }) {
    const limit = Math.min(40, Math.max(4, opts.limit | 0));

    let bucket = ((opts.seed % SEED_BUCKETS) + SEED_BUCKETS) % SEED_BUCKETS;
    let ids = await getShuffledIds(bucket);

    if (opts.viewerUserId) {
      const owned = await getViewerOwnedProductIds(opts.viewerUserId);
      if (owned.size > 0) ids = ids.filter((id) => !owned.has(id));
    }

    if (ids.length === 0) {
      return { products: [], nextPage: opts.page + 1, total: 0 };
    }

    const totalPages = Math.max(1, Math.ceil(ids.length / limit));
    const rotation = Math.floor(opts.page / totalPages);
    const effectivePage = opts.page % totalPages;

    if (rotation > 0) {
      bucket = (bucket + rotation) % SEED_BUCKETS;
      ids = await getShuffledIds(bucket);
      if (opts.viewerUserId) {
        const owned = await getViewerOwnedProductIds(opts.viewerUserId);
        if (owned.size > 0) ids = ids.filter((id) => !owned.has(id));
      }
    }

    const offset = effectivePage * limit;
    const sliceIds = ids.slice(offset, offset + limit);
    if (sliceIds.length === 0) {
      return { products: [], nextPage: opts.page + 1, total: ids.length };
    }

    const cards = await prisma.product.findMany({
      where: { id: { in: sliceIds } },
      select: {
        id: true,
        name: true,
        mrp: true,
        sellingPrice: true,
        brand: true,
        ratingAvg: true,
        ratingCount: true,
        images: {
          select: { url: true, sortOrder: true },
          orderBy: { sortOrder: 'asc' as const },
          take: 1,
        },
        shop: { select: { id: true, name: true, slug: true } },
      },
    });
    const byId = new Map(cards.map((c) => [c.id, c]));
    const products = sliceIds
      .map((id) => byId.get(id))
      .filter((c): c is NonNullable<typeof c> => !!c);

    return { products, nextPage: opts.page + 1, total: ids.length };
  }

  async getPersonalized(userId: number) {
    const [recentlyViewed, recommended] = await Promise.all([
      prisma.recentlyViewed.findMany({
        where: { userId },
        orderBy: { lastViewedAt: 'desc' },
        take: 12,
        select: {
          lastViewedAt: true,
          product: {
            select: {
              id: true,
              name: true,
              mrp: true,
              sellingPrice: true,
        brand: true,
              ratingAvg: true,
              ratingCount: true,
              isPublished: true,
              images: { take: 1, orderBy: { sortOrder: 'asc' as const } },
              shop: { select: { id: true, name: true, slug: true } },
            },
          },
        },
      }),
      trendingService.listRecommendations(userId),
    ]);
    return {
      recentlyViewed: recentlyViewed
        .filter((r) => r.product.isPublished)
        .map((r) => ({ lastViewedAt: r.lastViewedAt, product: r.product })),
      recommended,
    };
  }
}

export interface HomeFeedResponse {
  heroBanners: unknown[];
  adStripBanners: unknown[];
  promoBanners: unknown[];
  curatedRailBanners: unknown[];
  trending: Array<{ score: number; product: unknown }>;
  newArrivals: unknown[];
  categoryPucks: Array<{
    id: number;
    slug: string;
    name: string;
    imageUrl: string | null;
    iconName: string | null;
  }>;
}

export const homeService = new HomeService();
