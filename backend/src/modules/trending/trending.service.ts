import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';

const TRENDING_FOR_YOU_SLOT = 'for_you';
const TRENDING_WINDOW_HOURS = 24;
const TRENDING_TAKE_GLOBAL = 60;
const TRENDING_TAKE_BY_CATEGORY = 30;
const REC_CACHE_TAKE = 30;
const TRENDING_SNAPSHOT_RETENTION_DAYS = 7;

const productPublicSelect = {
  id: true,
  name: true,
  sku: true,
  mrp: true,
  sellingPrice: true,
        brand: true,
  ratingAvg: true,
  ratingCount: true,
  isPublished: true,
  shop: { select: { id: true, name: true, slug: true, isPublished: true } },
  images: {
    select: { url: true, sortOrder: true },
    orderBy: { sortOrder: 'asc' as const },
    take: 1,
  },
} as const;

interface AggRow {
  product_id: number;
  category_id: number | null;
  imp24h: number;
  taps24h: number;
  atc24h: number;
  purchases24h: number;
  wish24h: number;
  days_since_listing: number;
}

export class TrendingService {
  async recomputeWindow(): Promise<{ windowEnd: Date; products: number }> {
    const now = new Date();
    const since = new Date(now.getTime() - TRENDING_WINDOW_HOURS * 3_600_000);

    const rows = await prisma.$queryRaw<AggRow[]>`
      SELECT
        pe.product_id::int AS product_id,
        p.category_id      AS category_id,
        SUM(CASE WHEN pe.event_type = 'IMPRESSION'   THEN 1 ELSE 0 END)::float AS imp24h,
        SUM(CASE WHEN pe.event_type = 'TAP'          THEN 1 ELSE 0 END)::float AS taps24h,
        SUM(CASE WHEN pe.event_type = 'ADD_TO_CART'  THEN 1 ELSE 0 END)::float AS atc24h,
        SUM(CASE WHEN pe.event_type = 'PURCHASE'     THEN 1 ELSE 0 END)::float AS purchases24h,
        SUM(CASE WHEN pe.event_type = 'WISHLIST_ADD' THEN 1 ELSE 0 END)::float AS wish24h,
        GREATEST(0, EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 86400.0)::float AS days_since_listing
      FROM product_events pe
      JOIN products p ON p.id = pe.product_id
      WHERE pe.occurred_at >= ${since}
        AND p.is_active = true
      GROUP BY pe.product_id, p.category_id, p.created_at
    `;

    if (rows.length === 0) {
      logger.info({ windowEnd: now.toISOString() }, 'trending: no events in window');
      return { windowEnd: now, products: 0 };
    }

    type Upsert = { categoryId: number | null; productId: number; score: number };
    const byProductGlobal = new Map<number, number>();
    const perCategory: Upsert[] = [];

    for (const r of rows) {
      const score =
        0.05 * r.imp24h +
        0.3 * r.taps24h +
        2 * r.atc24h +
        10 * r.purchases24h +
        1 * r.wish24h -
        Math.exp(-r.days_since_listing / 30);

      if (r.category_id !== null) {
        perCategory.push({
          categoryId: r.category_id,
          productId: r.product_id,
          score,
        });
      }
      const prior = byProductGlobal.get(r.product_id) ?? 0;
      byProductGlobal.set(r.product_id, prior + score);
    }

    const globalRows: Upsert[] = Array.from(byProductGlobal.entries()).map(
      ([productId, score]) => ({ categoryId: null, productId, score }),
    );

    const allUpserts = [...perCategory, ...globalRows];

    const allProductIds = [...new Set(allUpserts.map((u) => u.productId))];
    const stillThere = await prisma.product.findMany({
      where: { id: { in: allProductIds } },
      select: { id: true },
    });
    const stillThereSet = new Set(stillThere.map((r) => r.id));
    const filteredUpserts = allUpserts.filter((u) => stillThereSet.has(u.productId));

    await prisma.trendingScore.deleteMany({
      where: { categoryId: null, windowEnd: now },
    });
    const writes = filteredUpserts.map((u) =>
      u.categoryId === null
        ? prisma.trendingScore.create({
            data: {
              categoryId: null,
              productId: u.productId,
              score: new Prisma.Decimal(u.score.toFixed(4)),
              windowEnd: now,
            },
          })
        : prisma.trendingScore.upsert({
            where: {
              categoryId_productId_windowEnd: {
                categoryId: u.categoryId,
                productId: u.productId,
                windowEnd: now,
              },
            },
            create: {
              categoryId: u.categoryId,
              productId: u.productId,
              score: new Prisma.Decimal(u.score.toFixed(4)),
              windowEnd: now,
            },
            update: {
              score: new Prisma.Decimal(u.score.toFixed(4)),
            },
          }),
    );
    const settled = await Promise.allSettled(writes);
    const failed = settled.filter((s) => s.status === 'rejected').length;
    if (failed > 0) {
      logger.warn({ failed }, 'trending: some upserts failed (likely FK race)');
    }

    const cutoff = new Date(
      now.getTime() - TRENDING_SNAPSHOT_RETENTION_DAYS * 86_400_000,
    );
    await prisma.trendingScore.deleteMany({
      where: { windowEnd: { lt: cutoff } },
    });

    logger.info(
      {
        windowEnd: now.toISOString(),
        products: byProductGlobal.size,
        rows: allUpserts.length,
      },
      'trending: recomputed',
    );
    return { windowEnd: now, products: byProductGlobal.size };
  }

  async listTrending(opts: { categoryId?: number | null; take?: number } = {}) {
    const limit = Math.min(
      100,
      Math.max(
        1,
        opts.take ??
          (opts.categoryId == null ? TRENDING_TAKE_GLOBAL : TRENDING_TAKE_BY_CATEGORY),
      ),
    );
    const latest = await prisma.trendingScore.findFirst({
      where: { categoryId: opts.categoryId ?? null },
      orderBy: { windowEnd: 'desc' },
      select: { windowEnd: true },
    });
    if (!latest) return [];

    const rows = await prisma.trendingScore.findMany({
      where: { categoryId: opts.categoryId ?? null, windowEnd: latest.windowEnd },
      orderBy: [{ score: 'desc' }, { productId: 'asc' }],
      take: limit,
      select: {
        score: true,
        product: { select: productPublicSelect },
      },
    });

    return rows.filter((r) => r.product.isPublished && r.product.shop?.isPublished);
  }

  async recomputeForUser(userId: number): Promise<{ count: number }> {
    const since = new Date(Date.now() - 30 * 86_400_000);

    const categoryRows = await prisma.$queryRaw<
      Array<{ category_id: number | null; weight: number }>
    >`
      SELECT p.category_id AS category_id,
             SUM(CASE WHEN pe.event_type = 'WISHLIST_ADD' THEN 3 ELSE 1 END)::float AS weight
      FROM product_events pe
      JOIN products p ON p.id = pe.product_id
      WHERE pe.user_id = ${userId}
        AND pe.occurred_at >= ${since}
        AND pe.event_type IN ('VIEW', 'WISHLIST_ADD')
      GROUP BY p.category_id
      ORDER BY weight DESC
      LIMIT 5
    `;
    const topCategoryIds = categoryRows
      .map((r) => r.category_id)
      .filter((id): id is number => id !== null);

    const shopRows = await prisma.$queryRaw<Array<{ shop_id: number }>>`
      SELECT DISTINCT p.shop_id
      FROM product_events pe
      JOIN products p ON p.id = pe.product_id
      WHERE pe.user_id = ${userId}
        AND pe.occurred_at >= ${since}
    `;
    const visitedShops = new Set(shopRows.map((r) => r.shop_id));

    const purchasedRows = await prisma.invoiceItem.findMany({
      where: {
        invoice: { status: 'CONFIRMED', party: { linkedUserId: userId } },
      },
      select: { productId: true },
    });
    const purchased = new Set(
      purchasedRows.map((r) => r.productId).filter((id): id is number => id !== null),
    );

    if (topCategoryIds.length === 0) {
      await prisma.recommendationCache.deleteMany({
        where: { userId, slot: TRENDING_FOR_YOU_SLOT },
      });
      return { count: 0 };
    }

    const candidateRows = await prisma.trendingScore.findMany({
      where: { categoryId: { in: topCategoryIds } },
      orderBy: { windowEnd: 'desc' },
      take: 300,
      select: {
        score: true,
        product: {
          select: { id: true, isPublished: true, shopId: true, shop: { select: { isPublished: true } } },
        },
      },
    });

    type Scored = { id: number; score: number };
    const aggregate = new Map<number, Scored>();
    for (const row of candidateRows) {
      const p = row.product;
      if (!p.isPublished || !p.shop?.isPublished) continue;
      const base = Number(row.score);
      let score = base;
      if (visitedShops.has(p.shopId)) score *= 1.2;
      if (purchased.has(p.id)) score *= 0.3;
      const prior = aggregate.get(p.id);
      if (!prior || prior.score < score) {
        aggregate.set(p.id, { id: p.id, score });
      }
    }

    const top = Array.from(aggregate.values())
      .sort((a, b) => b.score - a.score)
      .slice(0, REC_CACHE_TAKE)
      .map((r) => r.id);

    await prisma.recommendationCache.upsert({
      where: { userId_slot: { userId, slot: TRENDING_FOR_YOU_SLOT } },
      create: {
        userId,
        slot: TRENDING_FOR_YOU_SLOT,
        productIds: top,
      },
      update: {
        productIds: top,
        computedAt: new Date(),
      },
    });

    return { count: top.length };
  }

  async listRecommendations(userId: number, slot: string = TRENDING_FOR_YOU_SLOT) {
    const cache = await prisma.recommendationCache.findUnique({
      where: { userId_slot: { userId, slot } },
    });
    if (cache && cache.productIds.length > 0) {
      const products = await prisma.product.findMany({
        where: { id: { in: cache.productIds }, isPublished: true },
        select: productPublicSelect,
      });
      const byId = new Map(products.map((p) => [p.id, p]));
      return cache.productIds
        .map((id) => byId.get(id))
        .filter((p): p is NonNullable<typeof p> => p !== undefined);
    }
    const trending = await this.listTrending({ categoryId: null });
    return trending.map((r) => r.product);
  }

  async rebuildAllRecommendations(): Promise<{ users: number }> {
    const since = new Date(Date.now() - 30 * 86_400_000);
    const users = await prisma.$queryRaw<Array<{ user_id: number }>>`
      SELECT DISTINCT pe.user_id AS user_id
      FROM product_events pe
      WHERE pe.user_id IS NOT NULL
        AND pe.occurred_at >= ${since}
    `;
    let count = 0;
    for (const u of users) {
      await this.recomputeForUser(u.user_id);
      count += 1;
    }
    logger.info({ users: count }, 'recommendations: rebuilt');
    return { users: count };
  }
}

export const trendingService = new TrendingService();
