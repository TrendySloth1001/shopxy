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

/// One day's shop-wide engagement counts, for the trend line. Bucketed
/// on the UTC calendar day of the event.
export interface DailyEngagement {
  day: string;
  impressions: number;
  taps: number;
  views: number;
  addToCart: number;
  purchases: number;
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
  /// Shop-wide daily series across the whole window (independent of the
  /// product pagination) so the client can plot engagement over time.
  daily: DailyEngagement[];
  /// Opaque pagination cursor — caller passes back via ?cursor=… to
  /// fetch the next page. Null when there are no more rows.
  nextCursor: string | null;
}

interface DailyRow {
  day: Date;
  impressions: number;
  taps: number;
  views: number;
  add_to_cart: number;
  purchases: number;
}

interface HeatCellRow {
  dow: number;
  hour: number;
  purchases: number;
  views: number;
}

export interface RetentionResponse {
  from: string;
  to: string;
  totalCustomers: number;
  newCustomers: number;
  returningCustomers: number;
  /// returning ÷ total (0..1)
  repeatRate: number;
  /// customers with 2+ orders within the window
  repeatInPeriod: number;
  top: { name: string; orders: number; revenue: number }[];
}

interface RetentionRow {
  name: string | null;
  orders_in_range: number;
  revenue_in_range: number;
  returning: boolean;
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

    const daily = await this.getDailyEngagement(shopId, from, to);

    return {
      from: from.toISOString(),
      to: to.toISOString(),
      totals,
      products,
      daily,
      nextCursor,
    };
  }

  /// Shop-wide engagement bucketed by UTC day across the window. One
  /// extra aggregate alongside the per-product page; cheap with the
  /// (shop, occurred_at) index path through the product join.
  async getDailyEngagement(shopId: number, from: Date, to: Date): Promise<DailyEngagement[]> {
    const rows = await prisma.$queryRaw<DailyRow[]>`
      SELECT
        date_trunc('day', pe.occurred_at) AS day,
        COALESCE(SUM(CASE WHEN pe.event_type = 'IMPRESSION'   THEN 1 ELSE 0 END), 0)::float AS impressions,
        COALESCE(SUM(CASE WHEN pe.event_type = 'TAP'          THEN 1 ELSE 0 END), 0)::float AS taps,
        COALESCE(SUM(CASE WHEN pe.event_type = 'VIEW'         THEN 1 ELSE 0 END), 0)::float AS views,
        COALESCE(SUM(CASE WHEN pe.event_type = 'ADD_TO_CART'  THEN 1 ELSE 0 END), 0)::float AS add_to_cart,
        COALESCE(SUM(CASE WHEN pe.event_type = 'PURCHASE'     THEN 1 ELSE 0 END), 0)::float AS purchases
      FROM product_events pe
      JOIN products p ON p.id = pe.product_id
      WHERE p.shop_id = ${shopId}
        AND pe.occurred_at >= ${from}
        AND pe.occurred_at <  ${to}
      GROUP BY day
      ORDER BY day ASC
    `;
    return rows.map((r) => ({
      day: r.day.toISOString(),
      impressions: Math.trunc(r.impressions),
      taps: Math.trunc(r.taps),
      views: Math.trunc(r.views),
      addToCart: Math.trunc(r.add_to_cart),
      purchases: Math.trunc(r.purchases),
    }));
  }

  /// Purchases (and views) bucketed by IST day-of-week × hour for a
  /// "when do customers buy" heatmap. Returns only non-empty cells; the
  /// client fills the 7×24 grid.
  async getPurchaseHeatmap(shopId: number, from: Date, to: Date) {
    const rows = await prisma.$queryRaw<HeatCellRow[]>`
      SELECT
        EXTRACT(DOW  FROM pe.occurred_at AT TIME ZONE 'Asia/Kolkata')::int AS dow,
        EXTRACT(HOUR FROM pe.occurred_at AT TIME ZONE 'Asia/Kolkata')::int AS hour,
        COALESCE(SUM(CASE WHEN pe.event_type = 'PURCHASE' THEN 1 ELSE 0 END), 0)::float AS purchases,
        COALESCE(SUM(CASE WHEN pe.event_type = 'VIEW'     THEN 1 ELSE 0 END), 0)::float AS views
      FROM product_events pe
      JOIN products p ON p.id = pe.product_id
      WHERE p.shop_id = ${shopId}
        AND pe.occurred_at >= ${from}
        AND pe.occurred_at <  ${to}
        AND pe.event_type IN ('PURCHASE', 'VIEW')
      GROUP BY dow, hour
    `;
    return {
      from: from.toISOString(),
      to: to.toISOString(),
      cells: rows.map((r) => ({
        dow: r.dow,
        hour: r.hour,
        purchases: Math.trunc(r.purchases),
        views: Math.trunc(r.views),
      })),
    };
  }

  /// New-vs-returning customer split from confirmed SALE invoices.
  /// "Returning" = the customer had a confirmed sale before the window
  /// opened; "new" = their first purchase falls inside the window.
  /// Customers are keyed by party id, falling back to a name key for
  /// walk-ins. Revenue/orders are within the window.
  async getCustomerRetention(shopId: number, from: Date, to: Date): Promise<RetentionResponse> {
    const rows = await prisma.$queryRaw<RetentionRow[]>`
      WITH range_customers AS (
        SELECT
          COALESCE(party_id::text, 'name:' || COALESCE(customer_name, '')) AS cust,
          MAX(customer_name) AS name,
          COUNT(*)::int      AS orders_in_range,
          COALESCE(SUM(total), 0)::float AS revenue_in_range
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND invoice_date >= ${from} AND invoice_date < ${to}
        GROUP BY cust
      ),
      prior AS (
        SELECT DISTINCT COALESCE(party_id::text, 'name:' || COALESCE(customer_name, '')) AS cust
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND invoice_date < ${from}
      )
      SELECT rc.name AS name, rc.orders_in_range, rc.revenue_in_range,
             (p.cust IS NOT NULL) AS returning
      FROM range_customers rc
      LEFT JOIN prior p ON p.cust = rc.cust
    `;

    const total = rows.length;
    const returningCustomers = rows.filter((r) => r.returning).length;
    const repeatInPeriod = rows.filter((r) => r.orders_in_range >= 2).length;
    const top = rows
      .slice()
      .sort((a, b) => b.orders_in_range - a.orders_in_range || b.revenue_in_range - a.revenue_in_range)
      .slice(0, 10)
      .map((r) => ({
        name: r.name ?? 'Walk-in',
        orders: r.orders_in_range,
        revenue: roundTo(r.revenue_in_range, 2),
      }));

    return {
      from: from.toISOString(),
      to: to.toISOString(),
      totalCustomers: total,
      newCustomers: total - returningCustomers,
      returningCustomers,
      repeatRate: total > 0 ? roundTo(returningCustomers / total, 4) : 0,
      repeatInPeriod,
      top,
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
