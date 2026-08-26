import { z } from "zod";

export const DISCOUNT_TYPES = ["PERCENT", "FLAT"] as const;
export type DiscountType = (typeof DISCOUNT_TYPES)[number];

export const DISCOUNT_TYPE_LABELS: Record<DiscountType, string> = {
  PERCENT: "Percent off",
  FLAT: "Flat ₹ off",
};

export const couponSchema = z
  .object({
    id: z.coerce.string(),
    code: z.string(),
    title: z.string(),
    description: z.string().nullish(),
    discountType: z.enum(DISCOUNT_TYPES),
    discountValue: z.coerce.number().default(0),
    maxDiscount: z.union([z.null(), z.coerce.number()]).optional(),
    minOrderAmount: z.coerce.number().default(0),
    validFrom: z.string(),
    validUntil: z.string(),
    perUserLimit: z.coerce.number().default(0),
    totalCap: z.coerce.number().default(0),
    totalRedemptions: z.coerce.number().default(0),
    isPublic: z.boolean().default(false),
    firstOrderOnly: z.boolean().default(false),
    isActive: z.boolean().default(true),
    createdAt: z.string().optional(),
    updatedAt: z.string().optional(),
  })
  .passthrough();
export type Coupon = z.infer<typeof couponSchema>;

export const couponListSchema = z.object({
  data: z
    .array(couponSchema)
    .nullish()
    .transform((v) => v ?? []),
});

export const couponRedemptionSchema = z.object({
  id: z.coerce.string(),
  discountAmount: z.coerce.number().default(0),
  redeemedAt: z.string(),
  orderId: z.coerce.string().nullish(),
  user: z
    .object({ id: z.coerce.string(), name: z.string(), email: z.string() })
    .nullish(),
});
export type CouponRedemption = z.infer<typeof couponRedemptionSchema>;

export const couponRedemptionListSchema = z.object({
  data: z
    .array(couponRedemptionSchema)
    .nullish()
    .transform((v) => v ?? []),
});
