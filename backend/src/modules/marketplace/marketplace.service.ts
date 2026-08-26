import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';

const detailSelect = {
  id: true,
  name: true,
  description: true,
  sku: true,
  unit: true,
  countryOfOrigin: true,
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
  brand: true,
  soldLast30d: true,
  systemTags: true,
  contentBlocks: true,
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
  category: { select: { id: true, name: true, slug: true } },
} satisfies Prisma.ProductSelect;

export class MarketplaceService {
  async getPublicProduct(id: number, viewerUserId?: number) {
    const row = await prisma.product.findFirst({
      where: {
        id,
        isActive: true,
        isPublished: true,
        shop: { isPublished: true, ...(viewerUserId ? { ownerUserId: { not: viewerUserId } } : {}) },
      },
      select: detailSelect,
    });
    if (!row) return null;

    const FOURTEEN_DAYS_MS = 14 * 24 * 60 * 60 * 1000;
    const isNewArrival = Date.now() - row.createdAt.getTime() < FOURTEEN_DAYS_MS;
    const systemTags = isNewArrival && !row.systemTags.includes('NEW_ARRIVAL')
      ? [...row.systemTags, 'NEW_ARRIVAL']
      : row.systemTags;
    return { ...row, systemTags };
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

    const baseWhere: Prisma.ProductWhereInput = {
      categoryId: { in: ids },
      isActive: true,
      isPublished: true,
      shop: { isPublished: true, ...(opts.viewerUserId ? { ownerUserId: { not: opts.viewerUserId } } : {}) },
    };
    const filterWhere: Prisma.ProductWhereInput = {
      ...baseWhere,
      ...((opts.priceMin !== undefined || opts.priceMax !== undefined) && {
        sellingPrice: {
          ...(opts.priceMin !== undefined ? { gte: opts.priceMin } : {}),
          ...(opts.priceMax !== undefined ? { lte: opts.priceMax } : {}),
        },
      }),
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

    for (const r of rows) {
      await prisma.fbtCache.upsert({
        where: { productId: r.product_id },
        create: { productId: r.product_id, relatedIds: r.related_ids },
        update: { relatedIds: r.related_ids, computedAt: new Date() },
      });
    }
    return { products: rows.length };
  }

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
      const byId = new Map(rows.map((r) => [r.id, r]));
      return cached.relatedIds
        .map((id) => byId.get(id))
        .filter((r): r is NonNullable<typeof r> => r !== undefined);
    }

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
