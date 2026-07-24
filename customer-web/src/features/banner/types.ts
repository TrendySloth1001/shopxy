import { z } from "zod";

const zNum = z.union([z.number(), z.string()]).transform((v) => Number(v));

/** A product pinned to a banner, with its banner sale price. */
export const BannerProductSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  mrp: zNum,
  sellingPrice: zNum,
  brand: z.string().nullable().optional(),
  ratingAvg: z.union([z.number(), z.string()]).nullable().optional().transform((v) => (v == null ? null : Number(v))),
  ratingCount: z.number().default(0),
  shop: z.object({ id: z.coerce.string(), name: z.string(), slug: z.string().nullable().optional() }).nullable().optional(),
  images: z.array(z.object({ url: z.string(), sortOrder: z.number().default(0) })).default([]),
  discountPct: z.number().default(0),
  salePrice: zNum,
});
export type BannerProduct = z.infer<typeof BannerProductSchema>;

export const BannerDetailSchema = z.object({
  banner: z.object({
    id: z.coerce.string(),
    placement: z.string(),
    imageUrl: z.string(),
    linkUrl: z.string().nullable().optional(),
    productCount: z.number().default(0),
  }),
  products: z.array(BannerProductSchema).default([]),
});
export type BannerDetail = z.infer<typeof BannerDetailSchema>;
