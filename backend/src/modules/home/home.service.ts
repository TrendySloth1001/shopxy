import prisma from '../../infra/db/prisma.js';
import { bannersService } from '../banners/banners.service.js';
import { flashSalesService } from '../flash-sales/flash-sales.service.js';
import { brandSpotlightService } from '../brand-spotlight/brand-spotlight.service.js';
import { collectionsService } from '../collections/collections.service.js';
import { trendingService } from '../trending/trending.service.js';
import { categoriesService } from '../categories/categories.service.js';
import { promotionsService } from '../promotions/promotions.service.js';

// Locked product decision: 1 sponsored row per 5 organic. Mirrored
// from promotionsService.injectSponsoredIntoRail — kept here so the
// home batch can inline the merge without an extra round-trip path.
const SPONSORED_RATIO = 5;

/// Aggregates everything the customer home feed needs into a single
/// response so the app can render the first paint after one round-trip
/// instead of ten. Each section is loaded in parallel; a failure in one
/// section yields an empty array rather than failing the whole feed —
/// the home page should never be completely blank because a stale
/// trending snapshot or empty banner table broke one call.
export class HomeService {
  async getFeed(): Promise<HomeFeedResponse> {
    const [
      heroBanners,
      adStripBanners,
      promoBanners,
      curatedRailBanners,
      flashDeals,
      spotlights,
      collections,
      trendingGlobal,
      categoryTree,
    ] = await Promise.all([
      this._safe(() => bannersService.getActiveByPlacement('HERO')),
      this._safe(() => bannersService.getActiveByPlacement('AD_STRIP')),
      this._safe(() => bannersService.getActiveByPlacement('PROMO')),
      this._safe(() => bannersService.getActiveByPlacement('CURATED_RAIL')),
      this._safe(() => flashSalesService.listActivePublic({ limit: 12 })),
      this._safe(() => brandSpotlightService.listActive()),
      this._safe(() => collectionsService.listPublished()),
      this._safe(() => trendingService.listTrending({ categoryId: null, take: 30 })),
      // Top-level (root) categories only, with their immediate children
      // flattened to {id, slug, name, imageUrl} so the puck strip can
      // render without a second request.
      this._safe(() => categoriesService.getTree({ activeOnly: true })),
    ]);

    const organicTrending = trendingGlobal.map((r) => ({
      score: Number(r.score),
      product: r.product,
      id: r.product.id,
    }));

    // Layer sponsored slots into the trending rail at the locked
    // 1-in-5 ratio. Sponsored picks come with `isAd: true` +
    // `promotionId` so the customer renders the "AD" chip and the
    // impression event attributes back to the right promotion for
    // CPM billing. Wrapped in _safeInject so a misconfigured
    // promotions table never blanks the rail.
    const trendingWithSponsored = await this._safeInjectSponsored(organicTrending);

    return {
      heroBanners,
      adStripBanners,
      promoBanners,
      curatedRailBanners,
      flashDeals,
      brandSpotlights: spotlights,
      collections,
      trending: trendingWithSponsored,
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

  /// Interleaves sponsored picks into the organic trending rail at
  /// the locked 1-in-5 ratio. The earlier implementation routed
  /// enrichment through promotionsService.injectSponsoredIntoRail with
  /// an async enrich callback — that fired one findFirst per pick, so
  /// a 30-row rail meant 6 sequential round-trips on every home
  /// request. We now pick once, fetch every candidate product in a
  /// single findMany, then interleave against a Map. Wrapped in
  /// try/catch so a broken promotions table never blanks the rail.
  private async _safeInjectSponsored(
    organic: Array<{ score: number; product: { id: number; name: string; mrp: unknown; sellingPrice: unknown; ratingAvg: unknown; ratingCount: number; images: unknown[]; shop?: unknown }; id: number }>,
  ): Promise<Array<{ score: number; product: unknown; isAd?: boolean; promotionId?: number }>> {
    try {
      const sponsoredSlots = Math.ceil(organic.length / SPONSORED_RATIO);
      if (sponsoredSlots === 0) return organic;

      const picks = await promotionsService.pickSponsored({
        count: sponsoredSlots,
        excludeProductIds: organic.map((o) => o.id),
      });
      if (picks.length === 0) return organic;

      // ── Batch: one findMany resolves all sponsored picks ───────
      const products = await prisma.product.findMany({
        where: {
          id: { in: picks.map((p) => p.productId) },
          isActive: true,
          isPublished: true,
        },
        select: {
          id: true, name: true, mrp: true, sellingPrice: true,
          ratingAvg: true, ratingCount: true,
          images: { select: { url: true, sortOrder: true }, orderBy: { sortOrder: 'asc' }, take: 1 },
          shop: { select: { id: true, name: true, slug: true } },
        },
      });
      const productById = new Map(products.map((p) => [p.id, p]));

      const enriched: Array<{ score: number; product: unknown; isAd: true; promotionId: number; id: number }> = [];
      for (const pick of picks) {
        const product = productById.get(pick.productId);
        if (!product) continue;
        enriched.push({
          score: 0,
          id: product.id,
          product,
          isAd: true,
          promotionId: pick.promotionId,
        });
      }

      // ── Interleave: sponsored at every SPONSORED_RATIO-th slot ──
      const out: Array<{ score: number; product: unknown; isAd?: boolean; promotionId?: number }> = [];
      const remainingOrganic = [...organic];
      const remainingSponsored = [...enriched];
      let i = 0;
      while (remainingOrganic.length > 0 || remainingSponsored.length > 0) {
        const sponsoredSlot =
          i % SPONSORED_RATIO === 0 && remainingSponsored.length > 0;
        if (sponsoredSlot) {
          out.push(remainingSponsored.shift()!);
        } else if (remainingOrganic.length > 0) {
          out.push(remainingOrganic.shift()!);
        } else {
          out.push(remainingSponsored.shift()!);
        }
        i++;
      }
      return out;
    } catch {
      return organic;
    }
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
  flashDeals: unknown[];
  brandSpotlights: unknown[];
  collections: unknown[];
  /// May contain sponsored rows (`isAd: true` + `promotionId` set)
  /// interleaved with organic trending rows at the locked 1-in-5
  /// ratio. Customer mapper differentiates by the `isAd` flag.
  trending: Array<{
    score: number;
    product: unknown;
    isAd?: boolean;
    promotionId?: number;
  }>;
  categoryPucks: Array<{
    id: number;
    slug: string;
    name: string;
    imageUrl: string | null;
    iconName: string | null;
  }>;
}

export const homeService = new HomeService();
