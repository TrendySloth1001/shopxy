import {
  CatalogProductSchema,
  CategoryNodeSchema,
  PaginationSchema,
  ShopProfileSchema,
  type CatalogProduct,
  type CategoryNode,
  type Pagination,
  type ShopProfile,
  type SortOption,
} from "./types";
import { z } from "zod";

async function getJson(url: string): Promise<unknown> {
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) {
    let message = `Request failed (${res.status})`;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
  return res.json();
}

const ShopProductsResponseSchema = z.object({
  shop: ShopProfileSchema,
  data: z.array(CatalogProductSchema),
  pagination: PaginationSchema,
});

export async function fetchShopProducts(
  slug: string,
  opts: { page?: number; limit?: number; sort?: SortOption } = {},
): Promise<{ shop: ShopProfile; products: CatalogProduct[]; pagination: Pagination }> {
  const qp = new URLSearchParams();
  if (opts.page) qp.set("page", String(opts.page));
  if (opts.limit) qp.set("limit", String(opts.limit));
  if (opts.sort) qp.set("sort", opts.sort);
  const qs = qp.toString();
  const raw = await getJson(
    `/api/marketplace/shops/${encodeURIComponent(slug)}/products${qs ? `?${qs}` : ""}`,
  );
  const parsed = ShopProductsResponseSchema.parse(raw);
  return { shop: parsed.shop, products: parsed.data, pagination: parsed.pagination };
}

export async function fetchCategoryTree(): Promise<CategoryNode[]> {
  const raw = await getJson("/api/categories/tree");
  const result = z.object({ data: CategoryNodeSchema }).parse(raw);
  return result.data;
}

const CategoryProductsResponseSchema = z.object({
  category: z.object({
    id: z.coerce.string(),
    name: z.string(),
    slug: z.string(),
    imageUrl: z.string().nullable().optional(),
    iconName: z.string().nullable().optional(),
    children: z
      .array(
        z.object({ id: z.coerce.string(), name: z.string(), slug: z.string(), imageUrl: z.string().nullable().optional() }),
      )
      .default([]),
  }),
  data: z.array(CatalogProductSchema),
  pagination: PaginationSchema,
});

export type CategoryDetail = {
  id: string;
  name: string;
  slug: string;
  imageUrl: string | null;
  iconName: string | null;
  children: { id: string; name: string; slug: string; imageUrl?: string | null }[];
};

export async function fetchCategoryProducts(
  slug: string,
  opts: { page?: number; limit?: number; sort?: SortOption } = {},
): Promise<{ category: CategoryDetail; products: CatalogProduct[]; pagination: Pagination }> {
  const qp = new URLSearchParams();
  if (opts.page) qp.set("page", String(opts.page));
  if (opts.limit) qp.set("limit", String(opts.limit));
  if (opts.sort) qp.set("sort", opts.sort);
  const qs = qp.toString();
  const raw = await getJson(
    `/api/marketplace/categories/${encodeURIComponent(slug)}/products${qs ? `?${qs}` : ""}`,
  );
  const parsed = CategoryProductsResponseSchema.parse(raw);
  return {
    category: {
      ...parsed.category,
      imageUrl: parsed.category.imageUrl ?? null,
      iconName: parsed.category.iconName ?? null,
    },
    products: parsed.data,
    pagination: parsed.pagination,
  };
}
