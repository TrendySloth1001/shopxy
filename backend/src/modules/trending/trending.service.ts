import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { logger } from '../../shared/logging/logger.js';

/// Trending + recommendations (P6).
///
/// Two surfaces:
///   * Trending — per-(category, product) score, recomputed every 15
///     minutes from the last 24h of ProductEvent. Both a global
///     ("all") bucket and per-category buckets are produced in the
///     same pass so the home rail and category pages can query their
///     own slice without re-aggregating.
///   * Recommendations — per-user content-based shortlist (slot
///     "for_you"). Rebuilt nightly + on-purchase; the GET endpoint
///     reads cache first and falls back to global trending for cold-
///     start users.
///
/// The recompute is intentionally one big SQL — Postgres handles
/// per-product aggregation faster than streaming through JS, and
/// concurrent writes from the ingest path don't bother us (we read a
/// consistent snapshot, write a new windowEnd row, then sweep the
/// stale ones).

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
  shop: { select: { id: true, name: true, slug: true } },
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
  /// Recompute the trending snapshot. Writes one row per (category,
  /// product) plus one row per (null, product) for the global bucket.
  /// Older snapshots are kept for ~7d as a fallback during deploys
  /// (we never want the home rail to go dark) and swept by a separate
  /// pass — same cron tick, different statement.
  async recomputeWindow(): Promise<{ windowEnd: Date; products: number }> {
    const now = new Date();
    const since = new Date(now.getTime() - TRENDING_WINDOW_HOURS * 3_600_000);

    // One SQL aggregates everything we need per (product, category).
    // The CASE expressions in SUM are cheaper than six separate
    // queries and respect the (product_id, event_type, occurred_at)
    // index we built in P5.
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

    // Score + flatten: one upsert per (category, product) plus one
    // global (categoryId=null) bucket per product.
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

    // Re-check product existence right before write. Aggregation read
    // the row but the product could have been hard-deleted in the
    // gap (rare in prod, common in parallel tests). FK errors here
    // would abort the whole transaction.
    const allProductIds = [...new Set(allUpserts.map((u) => u.productId))];
    const stillThere = await prisma.product.findMany({
      where: { id: { in: allProductIds } },
      select: { id: true },
    });
    const stillThereSet = new Set(stillThere.map((r) => r.id));
    const filteredUpserts = allUpserts.filter((u) => stillThereSet.has(u.productId));

    // Raw INSERT … ON CONFLICT — Prisma's composite-key upsert can't
    // accept `categoryId: null` (NULLs are non-equal in unique
    // constraints), and we want both nullable and non-null buckets
    // in the same pass. Postgres handles both cleanly via the named
    // index when categoryId is non-null; for the global bucket we
    // simply DELETE the previous snapshot then INSERT.
    // Clear previous global rows for this windowEnd (rare collision —
    // recompute happens once per 15min, but safe).
    await prisma.trendingScore.deleteMany({
      where: { categoryId: null, windowEnd: now },
    });
    // Per-row writes with allSettled — a product hard-deleted between
    // the pre-flight existence check and the write (parallel-test
    // races, or a merchant deleting a SKU mid-recompute) just causes
    // that single row to fail; the rest of the snapshot still lands.
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

    // Sweep snapshots older than the retention window so the table
    // stays bounded. Same cron tick, separate statement.
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

  /// Public read — top N trending products. Picks the latest
  /// snapshot windowEnd (covers deploy-time staleness) and orders
  /// by score desc. categoryId=null → global bucket.
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

    // Marketplace surface should never expose unpublished products,
    // even if they trended internally (review pre-publish, etc).
    return rows.filter((r) => r.product.isPublished);
  }

  // ── Recommendations ────────────────────────────────────────────

  /// Compute the for-you slot for one user. Content-based:
  ///   1. find user's top-5 categories from their VIEW + WISHLIST_ADD
  ///      events in the last 30 days,
  ///   2. candidates = published products in those categories,
  ///   3. score = trending-rank-bonus + visited-shop bonus
  ///                - already-purchased penalty,
  ///   4. persist the top REC_CACHE_TAKE ids.
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

    // Shops the user has interacted with — used as a small bonus
    // multiplier to bias toward storefronts they already know.
    const shopRows = await prisma.$queryRaw<Array<{ shop_id: number }>>`
      SELECT DISTINCT p.shop_id
      FROM product_events pe
      JOIN products p ON p.id = pe.product_id
      WHERE pe.user_id = ${userId}
        AND pe.occurred_at >= ${since}
    `;
    const visitedShops = new Set(shopRows.map((r) => r.shop_id));

    // Already-purchased products — soft-penalised so we recommend
    // refills only when nothing else fits.
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
      // Cold-start user — wipe any stale cache so the GET endpoint
      // cleanly falls back to global trending.
      await prisma.recommendationCache.deleteMany({
        where: { userId, slot: TRENDING_FOR_YOU_SLOT },
      });
      return { count: 0 };
    }

    // Candidate pool: trending rows in the user's preferred categories.
    // Reads the most recent snapshot per category to stay fresh.
    const candidateRows = await prisma.trendingScore.findMany({
      where: { categoryId: { in: topCategoryIds } },
      orderBy: { windowEnd: 'desc' },
      take: 300,
      select: {
        score: true,
        product: {
          select: { id: true, isPublished: true, shopId: true },
        },
      },
    });

    type Scored = { id: number; score: number };
    const aggregate = new Map<number, Scored>();
    for (const row of candidateRows) {
      const p = row.product;
      if (!p.isPublished) continue;
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

  /// Public read for a logged-in user. Cache first; cold start falls
  /// back to global trending so the customer's first session still
  /// gets a populated rail.
  async listRecommendations(userId: number, slot: string = TRENDING_FOR_YOU_SLOT) {
    const cache = await prisma.recommendationCache.findUnique({
      where: { userId_slot: { userId, slot } },
    });
    if (cache && cache.productIds.length > 0) {
      const products = await prisma.product.findMany({
        where: { id: { in: cache.productIds }, isPublished: true },
        select: productPublicSelect,
      });
      // Preserve cache order — findMany returns in PK order otherwise.
      const byId = new Map(products.map((p) => [p.id, p]));
      return cache.productIds
        .map((id) => byId.get(id))
        .filter((p): p is NonNullable<typeof p> => p !== undefined);
    }
    // Cold start — fall back to global trending so the rail isn't
    // empty for new users.
    const trending = await this.listTrending({ categoryId: null });
    return trending.map((r) => r.product);
  }

  /// Nightly cron — rebuild the for-you cache for any user who has
  /// posted events in the last 30 days. Bounded by the unique user
  /// count in that window; sequential is fine at our scale.
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
