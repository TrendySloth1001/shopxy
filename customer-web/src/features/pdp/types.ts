import { z } from "zod";

// ── Image ─────────────────────────────────────────────────────────────────────

export const productImageSchema = z.object({
  id: z.number().optional(),
  url: z.string(),
  sortOrder: z.number(),
});
export type ProductImage = z.infer<typeof productImageSchema>;

// ── Variant ───────────────────────────────────────────────────────────────────

export const variantSchema = z.object({
  id: z.number(),
  sku: z.string().nullable().optional(),
  attributes: z.record(z.string(), z.string()).default({}),
  mrp: z.coerce.number(),
  sellingPrice: z.coerce.number(),
  stockQuantity: z.coerce.number(),
  imageUrls: z.array(z.string()).default([]),
  isDefault: z.boolean().default(false),
});
export type Variant = z.infer<typeof variantSchema>;

// ── Variant axis ──────────────────────────────────────────────────────────────

export const variantAxisSchema = z.object({
  name: z.string(),
  values: z.array(z.string()),
});
export type VariantAxis = z.infer<typeof variantAxisSchema>;

// ── Spec row / group ──────────────────────────────────────────────────────────

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

// ── Product offer ─────────────────────────────────────────────────────────────

export const productOfferSchema = z.object({
  kind: z.string(),
  headline: z.string(),
  code: z.string().nullable().optional(),
  description: z.string().nullable().optional(),
});
export type ProductOffer = z.infer<typeof productOfferSchema>;

// ── Bank offer ────────────────────────────────────────────────────────────────

export const bankOfferSchema = z.object({
  id: z.number(),
  headline: z.string(),
  description: z.string().nullable().optional(),
  bankName: z.string().nullable().optional(),
  discountType: z.string().nullable().optional(),
  discountValue: z.coerce.number().nullable().optional(),
  minOrderAmount: z.coerce.number().nullable().optional(),
  expiresAt: z.string().nullable().optional(),
});
export type BankOffer = z.infer<typeof bankOfferSchema>;

// ── Shop summary ──────────────────────────────────────────────────────────────

export const shopSummarySchema = z.object({
  id: z.number(),
  name: z.string(),
  slug: z.string(),
  logoUrl: z.string().nullable().optional(),
  rating: z.coerce.number().nullable().optional(),
  ratingCount: z.number().nullable().optional(),
});
export type ShopSummary = z.infer<typeof shopSummarySchema>;

// ── Category summary ──────────────────────────────────────────────────────────

export const categorySummarySchema = z.object({
  id: z.number(),
  name: z.string(),
  slug: z.string(),
});

// ── Full product detail ───────────────────────────────────────────────────────

export const productDetailSchema = z.object({
  id: z.number(),
  name: z.string(),
  description: z.string().nullable().optional(),
  sku: z.string().nullable().optional(),
  unit: z.string().nullable().optional(),
  mrp: z.coerce.number(),
  sellingPrice: z.coerce.number(),
  taxPercent: z.coerce.number().default(0),
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
  bankOffers: z.array(bankOfferSchema).default([]),
});
export type ProductDetail = z.infer<typeof productDetailSchema>;

// ── FBT card ──────────────────────────────────────────────────────────────────

export const fbtCardSchema = z.object({
  id: z.number(),
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

// ── Parsed specs helper ───────────────────────────────────────────────────────

export function parseSpecGroups(raw: unknown): SpecGroup[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item): SpecGroup[] => {
    const parsed = specGroupSchema.safeParse(item);
    return parsed.success ? [parsed.data] : [];
  });
}

// ── Parsed offers helper ──────────────────────────────────────────────────────

export function parseOffers(raw: unknown): ProductOffer[] {
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((item): ProductOffer[] => {
    const parsed = productOfferSchema.safeParse(item);
    return parsed.success ? [parsed.data] : [];
  });
}

