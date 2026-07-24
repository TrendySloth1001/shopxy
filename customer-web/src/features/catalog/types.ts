/**
 * Catalog presentation types — shop profile, category tree, and the product
 * card shape used across /shop/[slug], /c/[slug], and /spotlights.
 *
 * Ported from the Flutter customer app:
 *   - `marketplace/domain/entities/marketplace_product.dart`
 *   - `marketplace/domain/entities/marketplace_shop.dart`
 *   - `categories/data/models/category_dto.dart`
 */

import { z } from "zod";
import { zNum } from "@/shared/zod";

// ── Product card (list-select shape from /marketplace/shops/:slug/products) ──

export const CatalogProductSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  sku: z.string().optional(),
  unit: z.string().optional().nullable(),
  mrp: z.union([zNum, z.string()]).transform((v) => Number(v)),
  sellingPrice: z.union([zNum, z.string()]).transform((v) => Number(v)),
  ratingAvg: z
    .union([z.number(), z.string()])
    .nullable()
    .optional()
    .transform((v) => (v == null ? null : Number(v))),
  ratingCount: z.number().default(0),
  images: z
    .array(z.object({ url: z.string(), sortOrder: z.number().default(0) }))
    .default([]),
  shop: z
    .object({
      id: z.coerce.string(),
      name: z.string(),
      slug: z.string(),
    })
    .optional()
    .nullable(),
  category: z
    .object({ id: z.coerce.string(), name: z.string(), slug: z.string() })
    .optional()
    .nullable(),
});

export type CatalogProduct = z.infer<typeof CatalogProductSchema>;

// ── Shop shape from /marketplace/shops/:slug/products ──────────────────────

export const ShopProfileSchema = z.object({
  id: z.coerce.string(),
  name: z.string(),
  slug: z.string(),
  tagline: z.string().nullable().optional(),
  logoUrl: z.string().nullable().optional(),
  bannerUrl: z.string().nullable().optional(),
  rating: z
    .union([z.number(), z.string()])
    .nullable()
    .optional()
    .transform((v) => (v == null ? null : Number(v))),
  ratingCount: z.number().default(0),
});

export type ShopProfile = z.infer<typeof ShopProfileSchema>;

// ── Category (recursive tree node) ─────────────────────────────────────────

export interface CategoryNode {
  id: string;
  name: string;
  slug: string;
  imageUrl: string | null;
  iconName: string | null;
  description: string | null;
  parentId: string | null;
  isActive: boolean;
  _count: { products: number };
  children: CategoryNode[];
}

// Intermediate wire shape (before transform); input allows optional fields.
interface CategoryNodeWire {
  id: string;
  name: string;
  slug: string;
  imageUrl?: string | null;
  iconName?: string | null;
  description?: string | null;
  parentId?: string | null;
  isActive?: boolean;
  _count?: { products: number };
  children?: CategoryNodeWire[];
}

function parseCategoryNode(raw: CategoryNodeWire): CategoryNode {
  return {
    id: raw.id,
    name: raw.name,
    slug: raw.slug,
    imageUrl: raw.imageUrl ?? null,
    iconName: raw.iconName ?? null,
    description: raw.description ?? null,
    parentId: raw.parentId ?? null,
    isActive: raw.isActive ?? true,
    _count: raw._count ?? { products: 0 },
    children: (raw.children ?? []).map(parseCategoryNode),
  };
}

const CategoryNodeWireSchema: z.ZodType<CategoryNodeWire> = z.lazy(() =>
  z.object({
    id: z.coerce.string(),
    name: z.string(),
    slug: z.string(),
    imageUrl: z.string().nullable().optional(),
    iconName: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
    parentId: z.coerce.string().nullable().optional(),
    isActive: z.boolean().optional(),
    _count: z.object({ products: z.number() }).optional(),
    children: z.array(CategoryNodeWireSchema).optional(),
  }),
);

export const CategoryNodeSchema = z
  .array(CategoryNodeWireSchema)
  .transform((arr) => arr.map(parseCategoryNode));

// ── Pagination ──────────────────────────────────────────────────────────────

export interface Pagination {
  page: number;
  limit: number;
  total: number;
  pages: number;
}

export const PaginationSchema = z.object({
  page: z.number(),
  limit: z.number(),
  total: zNum,
  pages: z.number(),
});

// ── Sort options ────────────────────────────────────────────────────────────

export type SortOption = "popular" | "newest" | "price_asc" | "price_desc";

export const SORT_OPTIONS: { value: SortOption; label: string }[] = [
  { value: "popular", label: "Popular" },
  { value: "newest", label: "Newest" },
  { value: "price_asc", label: "Price: low to high" },
  { value: "price_desc", label: "Price: high to low" },
];
