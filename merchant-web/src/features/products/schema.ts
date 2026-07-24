import { z } from "zod";

/**
 * Product shapes, mirroring the backend products module
 * (`backend/src/modules/products/*`). Decimal money/qty fields are coerced to
 * numbers; nullable arrays are normalised to `[]`; unknown fields pass through.
 * Validated at the BFF boundary so screens work with a clean, typed object.
 */

/** Array that may arrive as null/undefined → always an array. */
const arr = <T extends z.ZodTypeAny>(s: T) =>
  z
    .array(s)
    .nullish()
    .transform((v) => v ?? []);

export const productImageSchema = z.object({
  id: z.coerce.string(),
  productId: z.coerce.string().optional(),
  url: z.string(),
  sortOrder: z.coerce.number().default(0),
  createdAt: z.string().optional(),
});
export type ProductImage = z.infer<typeof productImageSchema>;

export const categorySchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    parentId: z.coerce.string().nullish(),
    slug: z.string().nullish(),
    imageUrl: z.string().nullish(),
    iconName: z.string().nullish(),
    productCount: z.number().nullish(),
  })
  .passthrough();
export type Category = z.infer<typeof categorySchema>;

export const specRowSchema = z.object({ label: z.string(), value: z.string() });
export const specGroupSchema = z.object({
  title: z.string(),
  tab: z.string().nullish(),
  rows: arr(specRowSchema),
});
export type SpecGroup = z.infer<typeof specGroupSchema>;

export const offerSchema = z.object({
  kind: z.string(),
  headline: z.string(),
  detail: z.string().nullish(),
  code: z.string().nullish(),
});
export type ProductOffer = z.infer<typeof offerSchema>;

export const variantAxisSchema = z.object({
  name: z.string(),
  values: arr(z.string()),
});
export type VariantAxis = z.infer<typeof variantAxisSchema>;

export const variantSchema = z.object({
  id: z.coerce.string().optional(),
  sku: z.string(),
  barcode: z.string().nullish(),
  attributes: z.record(z.string(), z.string()).default({}),
  mrp: z.coerce.number().default(0),
  sellingPrice: z.coerce.number().default(0),
  purchasePrice: z.coerce.number().default(0),
  stockQuantity: z.coerce.number().default(0),
  imageUrls: arr(z.string()),
  isDefault: z.boolean().optional(),
  isActive: z.boolean().default(true),
  sortOrder: z.coerce.number().default(0),
});
export type ProductVariant = z.infer<typeof variantSchema>;

/** A+ content block — kind + free-form per-kind payload. */
export const contentBlockSchema = z.object({ kind: z.string() }).passthrough();
export type ContentBlock = z.infer<typeof contentBlockSchema>;

export const productSchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    description: z.string().nullish(),
    sku: z.string(),
    barcode: z.string().nullish(),
    hsnCode: z.string().nullish(),
    brand: z.string().nullish(),
    mrp: z.coerce.number().default(0),
    sellingPrice: z.coerce.number().default(0),
    purchasePrice: z.coerce.number().default(0),
    taxPercent: z.coerce.number().default(0),
    stockQuantity: z.coerce.number().default(0),
    lowStockThreshold: z.coerce.number().default(0),
    unit: z.string().default("PCS"),
    categoryId: z.coerce.string().nullish(),
    category: categorySchema.nullish(),
    isActive: z.boolean().default(true),
    isPublished: z.boolean().default(false),
    createdAt: z.string(),
    updatedAt: z.string(),
    images: arr(productImageSchema),
    ratingAvg: z.coerce.number().nullish(),
    ratingCount: z.coerce.number().default(0),
    tags: arr(z.string()),
    highlights: arr(z.string()),
    specs: arr(specGroupSchema),
    offers: arr(offerSchema),
    systemTags: arr(z.string()),
    totalSold: z.coerce.number().default(0),
    soldLast30d: z.coerce.number().default(0),
    contentBlocks: arr(contentBlockSchema),
    variantAxes: arr(variantAxisSchema),
    variants: arr(variantSchema),
    lastStockInAt: z.string().nullish(),
    lastStockOutAt: z.string().nullish(),
    lastVendorName: z.string().nullish(),
  })
  .passthrough();
export type Product = z.infer<typeof productSchema>;

export const productListSchema = z.object({
  data: z.array(productSchema),
  pagination: z
    .object({
      total: z.coerce.number().default(0),
      page: z.coerce.number().optional(),
      limit: z.coerce.number().optional(),
    })
    .passthrough(),
});
export type ProductList = z.infer<typeof productListSchema>;

/** Custom-field definition (shop-wide) + per-product value. */
export const customFieldDefSchema = z
  .object({
    id: z.coerce.string(),
    label: z.string().nullish(),
    name: z.string().nullish(),
    type: z.string().default("TEXT"),
    options: arr(z.string()),
  })
  .passthrough();
export type CustomFieldDef = z.infer<typeof customFieldDefSchema>;

export const customFieldValueSchema = z
  .object({
    definitionId: z.coerce.string(),
    value: z.string().nullish(),
  })
  .passthrough();
export type CustomFieldValue = z.infer<typeof customFieldValueSchema>;
