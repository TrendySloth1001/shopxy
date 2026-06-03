import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';
import { platformBankOffersService } from '../platform-bank-offers/platform-bank-offers.service.js';

/// Detail-level projection for a public marketplace product page.
/// Goes wide deliberately — the customer PDP needs gallery, shop
/// attribution, rating denorms, tags and an unwrapped category for
/// breadcrumb rendering.
const detailSelect = {
  id: true,
  name: true,
  description: true,
  sku: true,
  unit: true,
  mrp: true,
  sellingPrice: true,
  taxPercent: true,
  stockQuantity: true,
  ratingAvg: true,
  ratingCount: true,
  tags: true,
  highlights: true,
  specs: true,
  offers: true,
  totalSold: true,
  // Phase B additions — brand surfaces under the title, soldLast30d
  // drives "200+ bought in past month", systemTags renders curated
  // pills (BESTSELLER etc.) above the title.
  brand: true,
  soldLast30d: true,
  systemTags: true,
  // Phase C — A+ content blocks rendered inside the PDP Details tab.
  contentBlocks: true,
  // Phase E — variants + axis definition. Single-variant products
  // ship one row with attributes = {} so the customer client always
  // has at least one variantId to attach to add-to-cart.
  variantAxes: true,
  variants: {
    where: { isActive: true },
    orderBy: [{ isDefault: 'desc' as const }, { sortOrder: 'asc' as const }],
    select: {
      id: true,
      sku: true,
      attributes: true,
      mrp: true,
      sellingPrice: true,
      stockQuantity: true,
      imageUrls: true,
      isDefault: true,
    },
  },
  createdAt: true,
  images: {
    select: { id: true, url: true, sortOrder: true },
    orderBy: { sortOrder: 'asc' as const },
  },
  shop: {
    select: { id: true, name: true, slug: true, logoUrl: true, rating: true, ratingCount: true },
  },
  category: { select: { id: true, name: true, slug: true } },
  flashSales: {
    where: { isActive: true, startAt: { lte: new Date() }, endAt: { gte: new Date() } },
    select: { id: true, flashPrice: true, stockLimit: true, soldCount: true, endAt: true },
    take: 1,
  },
} satisfies Prisma.ProductSelect;

const listSelect = {
  id: true,
  name: true,
  sku: true,
  unit: true,
  mrp: true,
  sellingPrice: true,
  ratingAvg: true,
  ratingCount: true,
  totalSold: true,
  images: {
    select: { url: true, sortOrder: true },
    orderBy: { sortOrder: 'asc' as const },
    take: 1,
  },
  shop: { select: { id: true, name: true, slug: true } },
  // Category lets the customer client group/explore a shop's catalogue
  // by the merchant's own categories (e.g. the request-a-quote browser).
  category: { select: { id: true, name: true, slug: true } },
} satisfies Prisma.ProductSelect;

export class MarketplaceService {
  /// Public product detail. Returns null when the product is missing,
  /// inactive, or unpublished — the three states are deliberately
  /// indistinguishable from the caller's perspective so unpublished
  /// items don't leak metadata via 200-vs-404 probing.
  ///
  /// `viewerUserId` (the customer making the request) is excluded from
  /// reading their own shop's products — the "you can't buy from your
  /// own shop" marketplace guard rail at the read boundary.
  async getPublicProduct(id: number, viewerUserId?: number) {
    const row = await prisma.product.findFirst({
      where: {
        id,
        isActive: true,
        isPublished: true,
        ...(viewerUserId ? { shop: { ownerUserId: { not: viewerUserId } } } : {}),
      },
      select: detailSelect,
    });
    if (!row) return null;

    // Platform-curated bank offers — filtered to those whose
    // minOrderAmount ≤ selling price so the customer never sees a
    // tile they can't qualify for. Empty array if none are active.
    const bankOffers = await platformBankOffersService.listEligibleForProduct(
      Number(row.sellingPrice),
    );

    // NEW_ARRIVAL is computed at response time rather than stored —
    // the freshness window slides daily and a stored column would
    // require its own scheduler tick + write storm. Merging happens
    // here so the customer client only ever sees a single systemTags
    // array.
    const FOURTEEN_DAYS_MS = 14 * 24 * 60 * 60 * 1000;
    const isNewArrival = Date.now() - row.createdAt.getTime() < FOURTEEN_DAYS_MS;
    const systemTags = isNewArrival && !row.systemTags.includes('NEW_ARRIVAL')
      ? [...row.systemTags, 'NEW_ARRIVAL']
      : row.systemTags;
    return { ...row, systemTags, bankOffers };
  }

  async listShopProducts(opts: {
    slug: string;
    skip: number;
    limit: number;
    sort?: 'popular' | 'newest' | 'price_asc' | 'price_desc';
    viewerUserId?: number;
  }) {
    const shop = await prisma.shop.findFirst({
      where: {
        slug: opts.slug,
        isPublished: true,
        ...(opts.viewerUserId ? { ownerUserId: { not: opts.viewerUserId } } : {}),
      },
      select: {
        id: true, name: true, slug: true, tagline: true, logoUrl: true, bannerUrl: true,
        rating: true, ratingCount: true,
      },
    });
    if (!shop) return null;

    const orderBy: Prisma.ProductOrderByWithRelationInput =
      opts.sort === 'newest'    ? { createdAt: 'desc' }
      : opts.sort === 'price_asc'  ? { sellingPrice: 'asc' }
      : opts.sort === 'price_desc' ? { sellingPrice: 'desc' }
      :                              { totalSold: 'desc' };

    const where: Prisma.ProductWhereInput = {
      shopId: shop.id,
      isActive: true,
      isPublished: true,
    };
    const [data, total] = await Promise.all([
      prisma.product.findMany({
        where,
        select: listSelect,
        orderBy,
        skip: opts.skip,
        take: opts.limit,
      }),
      prisma.product.count({ where }),
    ]);
    return { shop, data, total };
  }

  /// Public products in a category, identified by slug. Includes
  /// products directly tagged with the category AND (when the slug
  /// resolves to a parent in the canonical taxonomy) products tagged
  /// with any of its children — so "Electronics" surfaces laptops,
  /// cameras, headphones, etc. without forcing the customer to drill
  /// down first. Returns null for an unknown slug.
  ///
  /// Filter axes (all optional, all server-validated upstream by the
  /// controller's zod-equivalent guards): price range, rating floor,
  /// in-stock-only toggle, shop id allowlist. `includeFacets` returns
  /// an additional aggregate payload describing the un-filtered set so
  /// the customer's filter sheet can show price-range bounds, rating
  /// histogram and brand list without a second round-trip.
  async listCategoryProducts(opts: {
    slug: string;
    skip: number;
    limit: number;
    sort?: 'popular' | 'newest' | 'price_asc' | 'price_desc';
    viewerUserId?: number;
    priceMin?: number;
    priceMax?: number;
    ratingMin?: number;
    inStock?: boolean;
    shopIds?: number[];
    includeFacets?: boolean;
  }) {
    const category = await prisma.category.findUnique({
      where: { slug: opts.slug },
      select: {
        id: true, name: true, slug: true, imageUrl: true, iconName: true,
        children: { select: { id: true, name: true, slug: true, imageUrl: true, iconName: true } },
      },
    });
    if (!category) return null;

    const ids = [category.id, ...category.children.map((c) => c.id)];

    const orderBy: Prisma.ProductOrderByWithRelationInput =
      opts.sort === 'newest'    ? { createdAt: 'desc' }
      : opts.sort === 'price_asc'  ? { sellingPrice: 'asc' }
      : opts.sort === 'price_desc' ? { sellingPrice: 'desc' }
      :                              { totalSold: 'desc' };

    // Base where (visibility + viewer-own-shop exclusion + category).
    // Filters are layered on top via destructured spreads so an unset
    // axis becomes a no-op rather than an explicit "match all" clause.
    const baseWhere: Prisma.ProductWhereInput = {
      categoryId: { in: ids },
      isActive: true,
      isPublished: true,
      ...(opts.viewerUserId
        ? { shop: { ownerUserId: { not: opts.viewerUserId } } }
        : {}),
    };
    const filterWhere: Prisma.ProductWhereInput = {
      ...baseWhere,
      ...((opts.priceMin !== undefined || opts.priceMax !== undefined) && {
        sellingPrice: {
          ...(opts.priceMin !== undefined ? { gte: opts.priceMin } : {}),
          ...(opts.priceMax !== undefined ? { lte: opts.priceMax } : {}),
        },
      }),
      // Important: Prisma maps `gte` against a NULL column to "not
      // matching" (null < anything is false), so this is the desired
      // behaviour even though it looks too permissive at first glance.
      ...(opts.ratingMin !== undefined && {
        ratingAvg: { gte: opts.ratingMin },
      }),
      ...(opts.inStock && { stockQuantity: { gt: 0 } }),
      ...(opts.shopIds && opts.shopIds.length > 0 && {
        shopId: { in: opts.shopIds },
      }),
    };

    const [data, total] = await Promise.all([
      prisma.product.findMany({
        where: filterWhere, select: listSelect, orderBy,
        skip: opts.skip, take: opts.limit,
      }),
      prisma.product.count({ where: filterWhere }),
    ]);

    // Facets reflect the BASE set (un-filtered) so the customer can
    // see "if I drop this filter, here's what comes back." Computed in
    // one parallel block to keep the cold-cache hit cheap.
    let facets: {
      priceMin: number;
      priceMax: number;
      ratingBuckets: { ge1: number; ge2: number; ge3: number; ge4: number; ge5: number };
      inStockCount: number;
      brands: Array<{ brand: string; count: number }>;
    } | undefined;
    if (opts.includeFacets) {
      const [priceAgg, ratingRows, inStockCount, brandRows] = await Promise.all([
        prisma.product.aggregate({
          where: baseWhere,
          _min: { sellingPrice: true },
          _max: { sellingPrice: true },
        }),
        prisma.product.findMany({
          where: { ...baseWhere, ratingAvg: { not: null } },
          select: { ratingAvg: true },
        }),
        prisma.product.count({
          where: { ...baseWhere, stockQuantity: { gt: 0 } },
        }),
        prisma.product.groupBy({
          by: ['brand'],
          where: { ...baseWhere, brand: { not: null } },
          _count: { brand: true },
          orderBy: { _count: { brand: 'desc' } },
          take: 25,
        }),
      ]);
      const bucket = (floor: number) =>
        ratingRows.filter(
          (r) => Number(r.ratingAvg ?? 0) >= floor,
        ).length;
      facets = {
        priceMin: Number(priceAgg._min.sellingPrice ?? 0),
        priceMax: Number(priceAgg._max.sellingPrice ?? 0),
        ratingBuckets: {
          ge1: bucket(1),
          ge2: bucket(2),
          ge3: bucket(3),
          ge4: bucket(4),
          ge5: bucket(5),
        },
        inStockCount,
        brands: brandRows
          .filter((b): b is typeof b & { brand: string } => b.brand !== null)
          .map((b) => ({ brand: b.brand, count: b._count.brand })),
      };
    }

    return { category, data, total, facets };
  }

  /// Phase G — recompute the "frequently bought together" cache for
  /// every product that's been on a CONFIRMED invoice in the last
  /// 90 days. For each anchor product, we score other products by
  /// co-occurrence count in the same invoice, filtered to the same
  /// shop (no cross-tenant leaks), and keep the top 5 — that fits a
  /// rail row nicely. Cold-start products (< 20 invoices in window)
  /// fall through to category siblings at read time, not here.
  ///
  /// One CTE-based UPSERT keeps the whole job under a single round
  /// trip and idempotent — re-running is safe.
  async recomputeFbtCache(): Promise<{ products: number }> {
    const rows = await prisma.$queryRaw<{ product_id: number; related_ids: number[] }[]>`
      WITH pair_counts AS (
        SELECT a.product_id AS anchor_id,
               b.product_id AS related_id,
               COUNT(*)::int AS cooc
          FROM invoice_items a
          JOIN invoice_items b
            ON a.invoice_id = b.invoice_id
           AND a.product_id <> b.product_id
          JOIN invoices i ON i.id = a.invoice_id
          JOIN products pa ON pa.id = a.product_id
          JOIN products pb ON pb.id = b.product_id
         WHERE i.status = 'CONFIRMED'
           AND i.created_at >= NOW() - INTERVAL '90 days'
           AND pa.shop_id = pb.shop_id
           AND pb.is_active = true
           AND pb.is_published = true
         GROUP BY a.product_id, b.product_id
      ),
      ranked AS (
        SELECT anchor_id,
               related_id,
               ROW_NUMBER() OVER (PARTITION BY anchor_id ORDER BY cooc DESC) AS rn
          FROM pair_counts
      ),
      top5 AS (
        SELECT anchor_id AS product_id,
               ARRAY_AGG(related_id ORDER BY rn) AS related_ids
          FROM ranked
         WHERE rn <= 5
         GROUP BY anchor_id
      )
      SELECT product_id, related_ids FROM top5
    `;

    // One write per anchor — cheap and the rows are bounded by the
    // active catalogue size, so the loop stays small. Upsert lets the
    // cron tick run safely after schema resets.
    for (const r of rows) {
      await prisma.fbtCache.upsert({
        where: { productId: r.product_id },
        create: { productId: r.product_id, relatedIds: r.related_ids },
        update: { relatedIds: r.related_ids, computedAt: new Date() },
      });
    }
    return { products: rows.length };
  }

  /// Public read for the customer PDP rail. Returns up to 5 slim
  /// product cards. Hits [FbtCache] first; on miss (cold-start) falls
  /// back to same-category siblings ranked by a cheap quality proxy
  /// (rating with a log-count smoother). Same-shop / same-tenant
  /// invariants are enforced at the SQL level.
  async getFrequentlyBoughtTogether(productId: number, viewerUserId?: number) {
    const anchor = await prisma.product.findFirst({
      where: { id: productId, isActive: true, isPublished: true },
      select: { id: true, shopId: true, categoryId: true },
    });
    if (!anchor) return [];

    const cached = await prisma.fbtCache.findUnique({ where: { productId } });
    if (cached && cached.relatedIds.length > 0) {
      const rows = await prisma.product.findMany({
        where: {
          id: { in: cached.relatedIds },
          isActive: true,
          isPublished: true,
          ...(viewerUserId
            ? { shop: { ownerUserId: { not: viewerUserId } } }
            : {}),
        },
        select: listSelect,
      });
      // Preserve the cache's order — Prisma's IN returns unordered.
      const byId = new Map(rows.map((r) => [r.id, r]));
      return cached.relatedIds
        .map((id) => byId.get(id))
        .filter((r): r is NonNullable<typeof r> => r !== undefined);
    }

    // Cold-start fallback — category siblings in the same shop scope,
    // ranked by rating with a log-count smoother to avoid one-review
    // products dominating.
    if (anchor.categoryId == null) return [];
    return prisma.product.findMany({
      where: {
        categoryId: anchor.categoryId,
        id: { not: productId },
        isActive: true,
        isPublished: true,
        ...(viewerUserId
          ? { shop: { ownerUserId: { not: viewerUserId } } }
          : {}),
      },
      select: listSelect,
      orderBy: [
        { ratingAvg: { sort: 'desc', nulls: 'last' } },
        { ratingCount: 'desc' },
      ],
      take: 5,
    });
  }
}

export const marketplaceService = new MarketplaceService();
