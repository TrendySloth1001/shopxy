import { z } from "zod";

/**
 * Product analytics shapes, mirroring the backend `analytics` module
 * (`/me/analytics/products`). Engagement funnel counts per product plus
 * shop-wide totals over a date range — impressions → taps → views → cart →
 * purchases, with CTR (taps/impressions) and CVR (purchases/views) as 0..1
 * ratios. No money here (that lives in Reports).
 */

const n = z.coerce.number().default(0);

export const analyticsTotalsSchema = z.object({
  impressions: n,
  taps: n,
  views: n,
  addToCart: n,
  purchases: n,
  wishlistAdd: n,
  ctr: n,
  cvr: n,
});
export type AnalyticsTotals = z.infer<typeof analyticsTotalsSchema>;

export const analyticsRowSchema = z
  .object({
    productId: z.number(),
    productName: z.string().nullish(),
    impressions: n,
    taps: n,
    views: n,
    addToCart: n,
    purchases: n,
    wishlistAdd: n,
    ctr: n,
    cvr: n,
  })
  .passthrough();
export type AnalyticsRow = z.infer<typeof analyticsRowSchema>;

export const productAnalyticsSchema = z
  .object({
    from: z.string().nullish(),
    to: z.string().nullish(),
    totals: analyticsTotalsSchema,
    products: z
      .array(analyticsRowSchema)
      .nullish()
      .transform((v) => v ?? []),
    nextCursor: z.string().nullish(),
  })
  .passthrough();
export type ProductAnalytics = z.infer<typeof productAnalyticsSchema>;

/** The sortable metric columns on the per-product table. */
export type AnalyticsSortKey =
  | "productName"
  | "impressions"
  | "taps"
  | "views"
  | "addToCart"
  | "purchases"
  | "ctr"
  | "cvr";
