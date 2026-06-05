import { z } from "zod";

/**
 * Flash-deal shapes, mirroring the backend `flash-sales` module's
 * `merchantSaleSelect`. Decimal money fields are coerced to numbers; dates
 * arrive as ISO strings. Validated at the BFF boundary.
 */

export const FLASH_STATUSES = ["active", "scheduled", "past"] as const;
export type FlashStatus = (typeof FLASH_STATUSES)[number];

export const FLASH_STATUS_LABELS: Record<FlashStatus, string> = {
  active: "Live",
  scheduled: "Scheduled",
  past: "Past",
};

const flashProductSchema = z
  .object({
    id: z.number(),
    name: z.string(),
    sku: z.string().nullish(),
    mrp: z.coerce.number().default(0),
    sellingPrice: z.coerce.number().default(0),
    images: z
      .array(z.object({ url: z.string() }).passthrough())
      .nullish()
      .transform((v) => v ?? []),
  })
  .passthrough();

export const flashSaleSchema = z
  .object({
    id: z.number(),
    productId: z.number(),
    flashPrice: z.coerce.number().default(0),
    stockLimit: z.coerce.number().default(0),
    soldCount: z.coerce.number().default(0),
    startAt: z.string(),
    endAt: z.string(),
    isActive: z.boolean().default(true),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
    product: flashProductSchema.nullish(),
  })
  .passthrough();
export type FlashSale = z.infer<typeof flashSaleSchema>;

export const flashSaleListSchema = z.object({
  data: z.array(flashSaleSchema).nullish().transform((v) => v ?? []),
});

// ── Analytics (GET /me/analytics/flash-deals/:id) ────────────────────────
export const flashAnalyticsSchema = z
  .object({
    flashSaleId: z.number(),
    productId: z.number(),
    productName: z.string(),
    startAt: z.string(),
    endAt: z.string(),
    stockLimit: z.coerce.number().default(0),
    soldCount: z.coerce.number().default(0),
    series: z
      .array(
        z.object({
          hour: z.string(),
          sold: z.coerce.number().default(0),
          taps: z.coerce.number().default(0),
          views: z.coerce.number().default(0),
        }),
      )
      .nullish()
      .transform((v) => v ?? []),
  })
  .passthrough();
export type FlashAnalytics = z.infer<typeof flashAnalyticsSchema>;
