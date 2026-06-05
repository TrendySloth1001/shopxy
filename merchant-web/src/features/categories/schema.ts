import { z } from "zod";

/**
 * Category shapes for the merchant browse surface. The backend `/categories`
 * taxonomy is platform-managed (writes are admin-only — see the "Category
 * taxonomy" admin screen); the merchant section is a read-only browse of the
 * tree plus a drill-down into the products of a category.
 */

export const categoryBaseSchema = z
  .object({
    id: z.number(),
    name: z.string(),
    slug: z.string().nullish(),
    description: z.string().nullish(),
    imageUrl: z.string().nullish(),
    iconName: z.string().nullish(),
    sortOrder: z.coerce.number().default(0),
    isActive: z.boolean().default(true),
    parentId: z.number().nullish(),
    // Backend returns `_count: { products }`; surface a flat count too.
    _count: z.object({ products: z.coerce.number().default(0) }).nullish(),
    productCount: z.coerce.number().nullish(),
  })
  .passthrough();

export type CategoryBase = z.infer<typeof categoryBaseSchema>;

/** A node in the taxonomy tree — base fields plus recursive children. */
export type CategoryNode = CategoryBase & { children: CategoryNode[] };

export const categoryNodeSchema: z.ZodType<CategoryNode> = categoryBaseSchema.extend({
  children: z.lazy(() => z.array(categoryNodeSchema)).default([]),
}) as z.ZodType<CategoryNode>;

export const categoryTreeSchema = z.object({
  data: z
    .array(categoryNodeSchema)
    .nullish()
    .transform((v) => v ?? []),
});

export const categoryDetailSchema = categoryBaseSchema;

/** Product count, tolerant of either `_count.products` or a flat field. */
export function categoryProductCount(c: CategoryBase): number {
  return c._count?.products ?? c.productCount ?? 0;
}

/**
 * Depth-first search for a node by id, returning the path from the root down to
 * (and including) the matched node — or null if not present. Used to render the
 * breadcrumb and resolve a category's children on its detail page.
 */
export function findCategoryPath(nodes: CategoryNode[], id: number): CategoryNode[] | null {
  for (const node of nodes) {
    if (node.id === id) return [node];
    const childPath = findCategoryPath(node.children ?? [], id);
    if (childPath) return [node, ...childPath];
  }
  return null;
}
