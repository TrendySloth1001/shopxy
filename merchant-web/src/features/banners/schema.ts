import { z } from "zod";

/** Banner placement slots on the customer home page. */
export const PLACEMENTS = ["HERO", "AD_STRIP", "PROMO", "CURATED_RAIL"] as const;
export type Placement = (typeof PLACEMENTS)[number];

export const PLACEMENT_LABELS: Record<Placement, string> = {
  HERO: "Hero carousel",
  AD_STRIP: "Ad strip",
  PROMO: "Promo row",
  CURATED_RAIL: "Curated rail",
};

/** One banner row as returned by the backend `/me/banners` endpoints. */
export const bannerSchema = z.object({
  id: z.number(),
  placement: z.enum(PLACEMENTS),
  imageUrl: z.string(),
  linkUrl: z.string().nullable().optional(),
  sortOrder: z.number().default(0),
  isActive: z.boolean().default(true),
  startAt: z.string().nullable().optional(),
  endAt: z.string().nullable().optional(),
  productCount: z.number().default(0),
});
export type Banner = z.infer<typeof bannerSchema>;

export const bannerListSchema = z.object({ data: z.array(bannerSchema) });

export const DISCOUNT_TYPES = ["PERCENT", "AMOUNT"] as const;
export type DiscountType = (typeof DISCOUNT_TYPES)[number];

/** A product pinned to a banner, as returned by `/me/banners/:id/products`. */
export const bannerProductSchema = z.object({
  id: z.number(),
  productId: z.number(),
  position: z.number().default(0),
  discountType: z.enum(DISCOUNT_TYPES),
  discountValue: z.coerce.number().default(0),
  salePrice: z.coerce.number().default(0),
  perUnitDiscount: z.coerce.number().default(0),
  product: z.object({
    id: z.number(),
    name: z.string(),
    sku: z.string().nullable().optional(),
    mrp: z.coerce.number().default(0),
    sellingPrice: z.coerce.number().default(0),
    images: z.array(z.object({ url: z.string(), sortOrder: z.number().default(0) })).default([]),
  }),
});
export type BannerProductRow = z.infer<typeof bannerProductSchema>;

export const bannerProductListSchema = z.object({ data: z.array(bannerProductSchema) });
