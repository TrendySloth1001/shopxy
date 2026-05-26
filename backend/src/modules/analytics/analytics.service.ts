import prisma from '../../infra/db/prisma.js';

/// Merchant analytics (P7).
///
/// Reads ProductEvent and scopes every aggregate to `shopId` via the
/// product join. Per-product roll-ups are computed in a single SQL
/// pass — the customer dashboard pulls one query per surface, not one
/// per metric.
///
/// All time ranges are inclusive on `from`, exclusive on `to`. The
/// controller passes ISO strings; the service normalises to Date
/// objects so callers don't need to repeat the parse.

interface PerProductRow {
  product_id: number;
  product_name: string;
  impressions: number;
  taps: number;
  views: number;
  add_to_cart: number;
  purchases: number;
  wishlist_add: number;
}

export interface ProductAnalyticsRow {
  productId: number;
  productName: string;
  impressions: number;
  taps: number;
  views: number;
  addToCart: number;
  purchases: number;
  wishlistAdd: number;
  ctr: number; // taps / impressions
  cvr: number; // purchases / views
}

export interface ProductAnalyticsResponse {
  from: string;
  to: string;
  totals: {
    impressions: number;
    taps: number;
    views: number;
    addToCart: number;
    purchases: number;
    wishlistAdd: number;
    ctr: number;
    cvr: number;
  };
  products: ProductAnalyticsRow[];
  /// Opaque pagination cursor — caller passes back via ?cursor=… to
  /// fetch the next page. Null when there are no more rows.
  nextCursor: string | null;
}

export type AnalyticsRangeTooLarge = {
  error: 'range_too_large';
  estimatedRows: number;
};

// Cheap upper-bound estimate: number of products in the caller's
// shop. The per-product aggregate is bounded by that count, so we
// short-circuit any request that would group beyond MAX_ESTIMATED_ROWS
// before ever issuing the heavy aggregate query.
export const ANALYTICS_MAX_ESTIMATED_ROWS = 10_000;
export const ANALYTICS_DEFAULT_LIMIT = 100;
export const ANALYTICS_MAX_LIMIT = 1000;

export function clampAnalyticsLimit(raw: unknown): number {
  const n = Number(raw);
  if (!Number.isFinite(n)) return ANALYTICS_DEFAULT_LIMIT;
  return Math.min(ANALYTICS_MAX_LIMIT, Math.max(1, Math.trunc(n)));
}

/// Cursor format: positive integer id, base64-url encoded so the
/// client can treat it as opaque. Returns null for malformed input.
export function parseAnalyticsCursor(raw: unknown): number | null {
  if (typeof raw !== 'string' || raw.length === 0) return null;
  try {
    const decoded = Buffer.from(raw, 'base64url').toString('utf8');
    const n = Number(decoded);
    return Number.isInteger(n) && n > 0 ? n : null;
  } catch {
    return null;
  }
}

export function encodeAnalyticsCursor(productId: number): string {
  return Buffer.from(String(productId), 'utf8').toString('base64url');
}

interface FlashSeriesRow {
  hour: Date;
  sold: number;
  taps: number;
  views: number;
}

export class AnalyticsService {
  /// Estimate how many product rows the per-product aggregate would
  /// emit for this shop. The aggregate groups by product, so the
  /// number of *active* products is the tight upper bound. Cheap
  /// indexed count — much faster than running the aggregate just to
  /// discover it returns 50k rows.
  async estimateProductRows(shopId: number): Promise<number> {
    return prisma.product.count({
      where: { shopId, isActive: true },
    });
  }

  /// Per-product aggregate for the caller's shop in the given window.
  /// Includes products that received zero events in the window so the
  /// merchant table can show "no traffic" for stale SKUs explicitly.
  ///
  /// Paginated by product id ascending after the cursor. Returns
  /// `nextCursor` when more rows exist for the next page.
  async getProductAnalytics(
    shopId: number,
    from: Date,
    to: Date,
    opts: { limit?: number; cursorProductId?: number | null } = {},
  ): Promise<ProductAnalyticsResponse> {
    const limit = clampAnalyticsLimit(opts.limit ?? ANALYTICS_DEFAULT_LIMIT);
    const cursor = opts.cursorProductId ?? null;
    // Fetch limit+1 so we can detect "there's more" without an extra
    // count round-trip; the +1 row gets sliced off before returning.
    const rows = await prisma.$queryRaw<PerProductRow[]>`
      SELECT
        p.id          AS product_id,
        p.name        AS product_name,
        COALESCE(SUM(CASE WHEN pe.event_type = 'IMPRESSION'   THEN 1 ELSE 0 END), 0)::float AS impressions,
        COALESCE(SUM(CASE WHEN pe.event_type = 'TAP'          THEN 1 ELSE 0 END), 0)::float AS taps,
        COALESCE(SUM(CASE WHEN pe.event_type = 'VIEW'         THEN 1 ELSE 0 END), 0)::float AS views,
        COALESCE(SUM(CASE WHEN pe.event_type = 'ADD_TO_CART'  THEN 1 ELSE 0 END), 0)::float AS add_to_cart,
        COALESCE(SUM(CASE WHEN pe.event_type = 'PURCHASE'     THEN 1 ELSE 0 END), 0)::float AS purchases,
        COALESCE(SUM(CASE WHEN pe.event_type = 'WISHLIST_ADD' THEN 1 ELSE 0 END), 0)::float AS wishlist_add
      FROM products p
      LEFT JOIN product_events pe
        ON pe.product_id = p.id
        AND pe.occurred_at >= ${from}
        AND pe.occurred_at <  ${to}
      WHERE p.shop_id = ${shopId}
        AND p.is_active = true
        AND (${cursor}::int IS NULL OR p.id > ${cursor}::int)
      GROUP BY p.id, p.name
      ORDER BY p.id ASC
      LIMIT ${limit + 1}
    `;

    const hasMore = rows.length > limit;
    const sliced = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore
      ? encodeAnalyticsCursor(sliced[sliced.length - 1].product_id)
      : null;

    const products: ProductAnalyticsRow[] = sliced.map((r) => {
      const ctr = r.impressions > 0 ? r.taps / r.impressions : 0;
      const cvr = r.views > 0 ? r.purchases / r.views : 0;
      return {
        productId: r.product_id,
        productName: r.product_name,
        impressions: Math.trunc(r.impressions),
        taps: Math.trunc(r.taps),
        views: Math.trunc(r.views),
        addToCart: Math.trunc(r.add_to_cart),
        purchases: Math.trunc(r.purchases),
        wishlistAdd: Math.trunc(r.wishlist_add),
        ctr: roundTo(ctr, 4),
        cvr: roundTo(cvr, 4),
      };
    });

    const totals = products.reduce(
      (acc, p) => {
        acc.impressions += p.impressions;
        acc.taps += p.taps;
        acc.views += p.views;
        acc.addToCart += p.addToCart;
        acc.purchases += p.purchases;
        acc.wishlistAdd += p.wishlistAdd;
        return acc;
      },
      {
        impressions: 0,
        taps: 0,
        views: 0,
        addToCart: 0,
        purchases: 0,
        wishlistAdd: 0,
        ctr: 0,
        cvr: 0,
      },
    );
    totals.ctr =
      totals.impressions > 0 ? roundTo(totals.taps / totals.impressions, 4) : 0;
    totals.cvr =
      totals.views > 0 ? roundTo(totals.purchases / totals.views, 4) : 0;

    return {
      from: from.toISOString(),
      to: to.toISOString(),
      totals,
      products,
      nextCursor,
    };
  }

  /// Per-flash-deal time series. Returns hourly buckets between the
  /// deal's [startAt, endAt] window with running sold count, taps,
  /// and views. Sold count comes from PURCHASE events on the product
  /// while the deal was live (a brief overcount is possible if a
  /// PURCHASE event fires for a non-flash order in the same window,
  /// but that's an upstream attribution problem — Phase 9 fixes it
  /// with sponsored-source tagging).
  async getFlashDealAnalytics(shopId: number, flashSaleId: number) {
    const sale = await prisma.flashSale.findUnique({
      where: { id: flashSaleId },
      include: { product: { select: { id: true, name: true, shopId: true } } },
    });
    if (!sale || sale.product.shopId !== shopId) return null;

    const series = await prisma.$queryRaw<FlashSeriesRow[]>`
      SELECT
        date_trunc('hour', pe.occurred_at) AS hour,
        COALESCE(SUM(CASE WHEN pe.event_type = 'PURCHASE' THEN 1 ELSE 0 END), 0)::float AS sold,
        COALESCE(SUM(CASE WHEN pe.event_type = 'TAP'      THEN 1 ELSE 0 END), 0)::float AS taps,
        COALESCE(SUM(CASE WHEN pe.event_type = 'VIEW'     THEN 1 ELSE 0 END), 0)::float AS views
      FROM product_events pe
      WHERE pe.product_id = ${sale.productId}
        AND pe.occurred_at >= ${sale.startAt}
        AND pe.occurred_at <  ${sale.endAt}
      GROUP BY hour
      ORDER BY hour ASC
    `;

    return {
      flashSaleId: sale.id,
      productId: sale.productId,
      productName: sale.product.name,
      startAt: sale.startAt.toISOString(),
      endAt: sale.endAt.toISOString(),
      stockLimit: sale.stockLimit,
      soldCount: sale.soldCount,
      series: series.map((r) => ({
        hour: r.hour.toISOString(),
        sold: Math.trunc(r.sold),
        taps: Math.trunc(r.taps),
        views: Math.trunc(r.views),
      })),
    };
  }
}

function roundTo(n: number, places: number): number {
  const m = 10 ** places;
  return Math.round(n * m) / m;
}

export const analyticsService = new AnalyticsService();
