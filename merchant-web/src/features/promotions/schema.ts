import { z } from "zod";

/**
 * Promotion shapes, mirroring the backend `promotions` module's
 * `merchantSelect`. All money is stored in paise (integers). CPM billing:
 * `cpmPaise` per 1000 impressions; the backend auto-pauses on budget/daily-cap.
 */

const promoProductSchema = z
  .object({
    id: z.number(),
    name: z.string(),
    sku: z.string().nullish(),
    sellingPrice: z.coerce.number().default(0),
  })
  .passthrough();

export const promotionSchema = z
  .object({
    id: z.number(),
    shopId: z.number(),
    productId: z.number(),
    budgetPaise: z.coerce.number().default(0),
    dailyCapPaise: z.coerce.number().default(0),
    cpmPaise: z.coerce.number().default(0),
    startAt: z.string(),
    endAt: z.string(),
    isActive: z.boolean().default(true),
    deliveredImpressions: z.coerce.number().default(0),
    spendPaise: z.coerce.number().default(0),
    spendTodayPaise: z.coerce.number().default(0),
    spendTodayDate: z.string().nullish(),
    pausedReason: z.string().nullish(),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
    product: promoProductSchema.nullish(),
  })
  .passthrough();
export type Promotion = z.infer<typeof promotionSchema>;

export const promotionListSchema = z.object({
  data: z.array(promotionSchema).nullish().transform((v) => v ?? []),
});
