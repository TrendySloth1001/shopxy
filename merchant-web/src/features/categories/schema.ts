import { z } from "zod";

export const categoryBaseSchema = z
  .object({
    id: z.coerce.string(),
    name: z.string(),
    slug: z.string().nullish(),
    description: z.string().nullish(),
    imageUrl: z.string().nullish(),
    iconName: z.string().nullish(),
    sortOrder: z.coerce.number().default(0),
    isActive: z.boolean().default(true),
    parentId: z.coerce.string().nullish(),
    _count: z.object({ products: z.coerce.number().default(0) }).nullish(),
    productCount: z.coerce.number().nullish(),
  })
  .passthrough();

export type CategoryBase = z.infer<typeof categoryBaseSchema>;

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

export function categoryProductCount(c: CategoryBase): number {
  return c._count?.products ?? c.productCount ?? 0;
}

export function findCategoryPath(nodes: CategoryNode[], id: string): CategoryNode[] | null {
  for (const node of nodes) {
    if (node.id === id) return [node];
    const childPath = findCategoryPath(node.children ?? [], id);
    if (childPath) return [node, ...childPath];
  }
  return null;
}
