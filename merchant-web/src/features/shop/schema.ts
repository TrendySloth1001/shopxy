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
    operatingHours: hours.nullish(),
    createdAt: z.string().nullish(),
    updatedAt: z.string().nullish(),
  })
  .passthrough();
export type Shop = z.infer<typeof shopSchema>;

/** Razorpay-Route linked account status — loosely typed (provider passthrough). */
export const payoutAccountSchema = z
  .object({
    id: z.number().nullish(),
    status: z.string().nullish(),
    accountId: z.string().nullish(),
    bankName: z.string().nullish(),
    last4: z.string().nullish(),
    createdAt: z.string().nullish(),
    updatedAt: z.string().nullish(),
  })
  .passthrough();
export type PayoutAccount = z.infer<typeof payoutAccountSchema>;
