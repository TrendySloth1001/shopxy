import { z } from "zod";

export const productImageSchema = z.object({
  id: z.coerce.string().optional(),
  url: z.string(),
  sortOrder: z.number(),
});
export type ProductImage = z.infer<typeof productImageSchema>;

export const variantSchema = z.object({
  id: z.coerce.string(),
  sku: z.string().nullable().optional(),
  attributes: z.record(z.string(), z.string()).default({}),
  mrp: z.coerce.number(),
  sellingPrice: z.coerce.number(),
  stockQuantity: z.coerce.number(),
  imageUrls: z.array(z.string()).default([]),
  isDefault: z.boolean().default(false),
});
export type Variant = z.infer<typeof variantSchema>;

export const variantAxisSchema = z.object({
  name: z.string(),
  values: z.array(z.string()),
});
export type VariantAxis = z.infer<typeof variantAxisSchema>;

export const specRowSchema = z.object({
  label: z.string(),
  value: z.string(),
});
export const specGroupSchema = z.object({
  title: z.string(),
  tab: z.string().nullable().optional(),
  rows: z.array(specRowSchema),
});
export type SpecRow = z.infer<typeof specRowSchema>;
export type SpecGroup = z.infer<typeof specGroupSchema>;

export const productOfferSchema = z.object({
  kind: z.string(),
  headline: z.string(),
  code: z.string().nullable().optional(),
  description: z.string().nullable().optional(),
});
export type ProductOffer = z.infer<typeof productOfferSchema>;

export const shopSummarySchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  slug: z.string(),
  logoUrl: z.string().nullable().optional(),
  rating: z.coerce.number().nullable().optional(),
  ratingCount: z.number().nullable().optional(),
  legalName: z.string().nullable().optional(),
  address: z.string().nullable().optional(),
  gstin: z.string().nullable().optional(),
  supportEmail: z.string().nullable().optional(),
  supportPhone: z.string().nullable().optional(),
  locationCity: z.string().nullable().optional(),
  locationState: z.string().nullable().optional(),
});
export type ShopSummary = z.infer<typeof shopSummarySchema>;

export const categorySummarySchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  slug: z.string(),
});

export const productDetailSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  description: z.string().nullable().optional(),
  sku: z.string().nullable().optional(),
  unit: z.string().nullable().optional(),
  mrp: z.coerce.number(),
  sellingPrice: z.coerce.number(),
  taxPercent: z.coerce.number().default(0),
  countryOfOrigin: z.string().nullable().optional(),
  stockQuantity: z.coerce.number(),
  ratingAvg: z.coerce.number().nullable().optional(),
  ratingCount: z.number().default(0),
  tags: z.array(z.string()).default([]),
  highlights: z.array(z.string()).default([]),
  specs: z.unknown().default([]),
  offers: z.unknown().default([]),
  totalSold: z.number().default(0),
  brand: z.string().nullable().optional(),
  soldLast30d: z.number().default(0),
  systemTags: z.array(z.string()).default([]),
  contentBlocks: z.unknown().default([]),
  variantAxes: z.array(variantAxisSchema).nullish().transform((v) => v ?? []),
  variants: z.array(variantSchema).default([]),
  createdAt: z.string().optional(),
  images: z.array(productImageSchema).default([]),
  shop: shopSummarySchema.nullable().optional(),
  category: categorySummarySchema.nullable().optional(),
});
export type ProductDetail = z.infer<typeof productDetailSchema>;

export const fbtCardSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  sku: z.string().nullable().optional(),
  unit: z.string().nullable().optional(),
  mrp: z.coerce.number(),
  sellingPrice: z.coerce.number(),
  ratingAvg: z.coerce.number().nullable().optional(),
  ratingCount: z.number().default(0),
  totalSold: z.number().default(0),
  images: z.array(productImageSchema).default([]),
  shop: shopSummarySchema.nullable().optional(),
  category: categorySummarySchema.nullable().optional(),
});
export type FbtCard = z.infer<typeof fbtCardSchema>;

export function parseSpecGroups(raw: unknown): SpecGroup[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item): SpecGroup[] => {
    const parsed = specGroupSchema.safeParse(item);
    return parsed.success ? [parsed.data] : [];
  });
}

export function parseOffers(raw: unknown): ProductOffer[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item): ProductOffer[] => {
    const parsed = productOfferSchema.safeParse(item);
    return parsed.success ? [parsed.data] : [];
  });
}
