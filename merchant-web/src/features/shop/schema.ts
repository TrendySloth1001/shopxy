import { z } from "zod";

/** Merchant shop shape, mirroring `merchantShopSelect` in shop.service.ts. */

export const DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"] as const;
export type Day = (typeof DAYS)[number];
export const DAY_LABELS: Record<Day, string> = {
  mon: "Monday",
  tue: "Tuesday",
  wed: "Wednesday",
  thu: "Thursday",
  fri: "Friday",
  sat: "Saturday",
  sun: "Sunday",
};

export const REFUND_MODES = ["WALLET", "ORIGINAL", "REPLACEMENT"] as const;
export type RefundMode = (typeof REFUND_MODES)[number];
export const REFUND_MODE_LABELS: Record<RefundMode, string> = {
  WALLET: "Store wallet credit",
  ORIGINAL: "Original payment method",
  REPLACEMENT: "Replacement only",
};

export const CANCELLATION_POLICIES = [
  "UNTIL_CONFIRMED",
  "UNTIL_PACKED",
  "UNTIL_SHIPPED",
  "UNTIL_DELIVERED",
] as const;
export type CancellationPolicy = (typeof CANCELLATION_POLICIES)[number];
export const CANCELLATION_POLICY_LABELS: Record<CancellationPolicy, string> = {
  UNTIL_CONFIRMED: "Until I confirm the order",
  UNTIL_PACKED: "Until packed",
  UNTIL_SHIPPED: "Until shipped (recommended)",
  UNTIL_DELIVERED: "Until delivered",
};

/** Return window in days; 0 means no limit. */
export const returnWindowDaysSchema = z.coerce.number().int().min(0).max(365);

const hours = z.record(
  z.string(),
  z.tuple([z.string(), z.string()]),
);

export const shopSchema = z
  .object({
    id: z.number(),
    name: z.string(),
    slug: z.string().nullish(),
    tagline: z.string().nullish(),
    logoUrl: z.string().nullish(),
    bannerUrl: z.string().nullish(),
    rating: z.coerce.number().nullish(),
    ratingCount: z.coerce.number().default(0),
    isVerified: z.boolean().default(false),
    isPublished: z.boolean().default(false),
    locationCity: z.string().nullish(),
    locationState: z.string().nullish(),
    returnPolicy: z.string().nullish(),
    shippingPolicy: z.string().nullish(),
    refundPolicy: z.string().nullish(),
    vacationMode: z.boolean().default(false),
    vacationMessage: z.string().nullish(),
    returnsEnabled: z.boolean().default(false),
    returnWindowDays: returnWindowDaysSchema.default(0),
    refundMode: z.enum(REFUND_MODES).default("ORIGINAL"),
    returnPolicyNote: z.string().max(2048).nullish(),
    cancellationPolicy: z.enum(CANCELLATION_POLICIES).default("UNTIL_SHIPPED"),
    operatingHours: hours.nullish(),
    createdAt: z.string().nullish(),
    updatedAt: z.string().nullish(),
  })
  .passthrough();
export type Shop = z.infer<typeof shopSchema>;

/** Razorpay-Route linked account — matches the backend `LinkedAccountView`. */
export const payoutAccountSchema = z
  .object({
    shopId: z.number().nullish(),
    providerAccountId: z.string().nullish(),
    kycStatus: z.string().nullish(),
    payoutsEnabled: z.boolean().nullish(),
    email: z.string().nullish(),
    contactName: z.string().nullish(),
    businessType: z.string().nullish(),
    // Legacy fields tolerated for forward/backward compat.
    status: z.string().nullish(),
    accountId: z.string().nullish(),
  })
  .passthrough();
export type PayoutAccount = z.infer<typeof payoutAccountSchema>;
