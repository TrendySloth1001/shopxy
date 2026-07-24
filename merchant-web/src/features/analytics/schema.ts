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
    productId: z.coerce.string(),
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

export const dailyEngagementSchema = z.object({
  day: z.string(),
  impressions: n,
  taps: n,
  views: n,
  addToCart: n,
  purchases: n,
});
export type DailyEngagement = z.infer<typeof dailyEngagementSchema>;

export const productAnalyticsSchema = z
  .object({
    from: z.string().nullish(),
    to: z.string().nullish(),
    totals: analyticsTotalsSchema,
    products: z
      .array(analyticsRowSchema)
      .nullish()
      .transform((v) => v ?? []),
    daily: z
      .array(dailyEngagementSchema)
      .nullish()
      .transform((v) => v ?? []),
    nextCursor: z.string().nullish(),
  })
  .passthrough();
export type ProductAnalytics = z.infer<typeof productAnalyticsSchema>;

export const heatmapSchema = z.object({
  cells: z
    .array(z.object({ dow: z.coerce.number(), hour: z.coerce.number(), purchases: n, views: n }))
    .nullish()
    .transform((v) => v ?? []),
});
export type Heatmap = z.infer<typeof heatmapSchema>;

export const retentionSchema = z.object({
  totalCustomers: n,
  newCustomers: n,
  returningCustomers: n,
  repeatRate: n,
  repeatInPeriod: n,
  top: z
    .array(z.object({ name: z.string().nullish(), orders: n, revenue: n }))
    .nullish()
    .transform((v) => v ?? []),
});
export type Retention = z.infer<typeof retentionSchema>;

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
