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
});
export type Banner = z.infer<typeof bannerSchema>;

export const bannerListSchema = z.object({ data: z.array(bannerSchema) });
