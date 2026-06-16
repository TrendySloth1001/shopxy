import prisma from '../../infra/db/prisma.js';
import {
  getShuffledIds,
  getViewerOwnedProductIds,
  SEED_BUCKETS,
} from './endless-cache.service.js';
import { bannersService } from '../banners/banners.service.js';
import { trendingService } from '../trending/trending.service.js';
import { categoriesService } from '../categories/categories.service.js';

/// Aggregates everything the customer home feed needs into a single
/// response so the app can render the first paint after one round-trip.
/// Each section is loaded in parallel; a failure in one section yields
/// an empty array rather than failing the whole feed — the home page
/// should never be completely blank because a stale trending snapshot
/// or empty banner table broke one call.
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
      // Top-level (root) categories only, with their immediate children
      // flattened to {id, slug, name, imageUrl} so the puck strip can
      // render without a second request.
      this._safe(() => categoriesService.getTree({ activeOnly: true })),
      // "Just landed" rail — top 20 most recently created published
      // products. Same select shape as the trending row so the customer
      // mapper can re-use its product-card extractor.
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

  /// "Just landed" rail — newest published products. Single SELECT
  /// ordered by `created_at desc`, capped at `take`. Cheap (uses the
  /// `(shop_id, is_published)` index for the WHERE then sorts the
  /// already-narrow result by createdAt). Same select shape as the
  /// trending card so the customer can re-use its mapper.
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

  /// Section-level fallback. Logging the error here (rather than
  /// throwing) keeps the page rendering — a missing rail is better
  /// than a 500.
  private async _safe<T>(fn: () => Promise<T[]>): Promise<T[]> {
    try {
      return await fn();
    } catch {
      return [];
    }
  }

  /// Trending sliced by category — used to populate the per-category
  /// rails (e.g. "Trending in Fashion") without making the home/feed
  /// payload balloon. Customer app calls this lazily as the user
  /// scrolls into a category-specific rail.
  async getCategoryRail(categoryId: number, take = 10) {
    const rows = await trendingService.listTrending({ categoryId, take });
    return rows.map((r) => ({ score: Number(r.score), product: r.product }));
  }

  /// Endless-scroll product page. The customer home tab keeps requesting
  /// the next page as the user scrolls; this method never returns "no
  /// more" — once the catalog is exhausted at the current rotation,
  /// the next call reshuffles with a derived seed and continues. The
  /// only stop signal is the upstream rate-limiter.
  ///
  /// Cache architecture (see `endless-cache.service.ts`):
  ///   - Client `seed` is bucketed to `seed % SEED_BUCKETS` (256). The
  ///     bounded seed space means we maintain at most 256 distinct
  ///     shuffles across all concurrent users, each cached in Redis
  ///     for 10 minutes. Cache hit rate approaches 100% steady-state.
  ///   - Each bucket's shuffled id list is a single Postgres SELECT
  ///     done once per TTL; every page-load after that is a slice of
  ///     the cached array (no DB round-trip for ordering).
  ///   - Viewer-owns-own-shop filter is a separate Redis-cached set
  ///     subtracted from the slice in memory, so the catalog shuffle
  ///     stays universal (no per-user shuffle re-build).
  ///   - The product cards themselves come from one `findMany` on the
  ///     final slice. Total DB cost per request in cache-warm steady
  ///     state: one short findMany. ~5 ms.
  ///
  /// Wrap-around (the "endless" part): once the user's page count
  /// crosses the bucket size, we rotate to the NEXT bucket so the
  /// next sweep through the catalog has a different ordering. The
  /// rotation is folded into the bucket index, not a per-request
  /// seed mutation, so the rotated bucket is itself cached.
  async getEndlessPage(opts: { seed: number; page: number; limit: number; viewerUserId?: number }) {
    const limit = Math.min(40, Math.max(4, opts.limit | 0));

    // Pull (cached) full shuffled id list for this bucket. Filter out
    // viewer-owned products if signed in. Slice with offset / limit.
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

    // Catalog sweep complete → rotate to a different cached bucket so
    // the next pass shuffles differently. Adding `rotation` keeps the
    // mapping deterministic per (seed, page).
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

    // Single findMany for the cards. Prisma doesn't preserve the
    // IN-clause ordering, so we re-sort against `sliceIds`.
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

  /// Auth-gated counterpart to /home/feed: caller's recently viewed +
  /// their for-you recommendations. Returns empty arrays for cold-start
  /// users — UI hides the section when empty.
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
