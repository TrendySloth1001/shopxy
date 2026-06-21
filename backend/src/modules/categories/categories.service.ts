import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';

/// Normalises to URL-safe lowercase-with-dashes. Identical to the shop
/// slugger but kept separate to avoid cross-feature coupling — if one
/// rule diverges later it shouldn't drag the other.
function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

async function uniqueSlug(base: string, excludeId?: number): Promise<string> {
  let candidate = base || 'category';
  let suffix = 1;
  for (;;) {
    const existing = await prisma.category.findUnique({
      where: { slug: candidate },
      select: { id: true },
    });
    if (!existing || existing.id === excludeId) return candidate;
    suffix += 1;
    candidate = `${base}-${suffix}`;
  }
}

/// Walks `parentId → grandparent → …` from `startId` looking for `targetId`.
/// Used by updateCategory to reject re-parenting that would form a cycle.
/// Bounded by `maxDepth` so a corrupted tree can't hang the request.
async function wouldFormCycle(
  startId: number,
  targetId: number,
  maxDepth = 32,
): Promise<boolean> {
  let cursor: number | null = startId;
  for (let i = 0; cursor !== null && i < maxDepth; i++) {
    if (cursor === targetId) return true;
    const next: { parentId: number | null } | null = await prisma.category.findUnique({
      where: { id: cursor },
      select: { parentId: true },
    });
    cursor = next?.parentId ?? null;
  }
  return false;
}

export class CategoriesService {
  async createCategory(data: {
    name: string;
    description?: string;
    imageUrl?: string;
    iconName?: string;
    sortOrder?: number;
    parentId?: number | null;
  }) {
    const slug = await uniqueSlug(slugify(data.name));
    return prisma.category.create({
      data: {
        name: data.name,
        slug,
        description: data.description,
        imageUrl: data.imageUrl,
        iconName: data.iconName,
        sortOrder: data.sortOrder,
        parentId: data.parentId ?? null,
      },
    });
  }

  async listCategories(options: {
    activeOnly: boolean;
    search?: string;
    page: number;
    limit: number;
    skip: number;
  }) {
    // Composite filter: active flag + optional case-insensitive name
    // contains-search. Needed once a shop has more categories than fit
    // on a horizontal pill strip — the picker UI lazy-fetches matches
    // as the user types.
    const where: Prisma.CategoryWhereInput = {};
    if (options.activeOnly) where.isActive = true;
    if (options.search && options.search.trim().length > 0) {
      where.name = { contains: options.search.trim(), mode: 'insensitive' };
    }

    const [categories, total] = await Promise.all([
      prisma.category.findMany({
        where,
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
        skip: options.skip,
        take: options.limit,
        include: { _count: { select: { products: true } } },
      }),
      prisma.category.count({ where }),
    ]);

    return { categories, total };
  }

  /// Full taxonomy tree in one query. Each row arrives with the flat
  /// {id, parentId, …} fields; we assemble parent → children references
  /// in O(N) memory client-side. For the depth we expect (<5 levels,
  /// ~hundreds of leaves) this beats N recursive Postgres CTE calls
  /// from the merchant editor.
  async getTree(options: { activeOnly?: boolean } = {}) {
    const rows = await prisma.category.findMany({
      where: options.activeOnly ? { isActive: true } : undefined,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: { _count: { select: { products: true } } },
    });
    type Node = (typeof rows)[number] & { children: Node[] };
    const byId = new Map<number, Node>();
    for (const r of rows) byId.set(r.id, { ...r, children: [] });
    const roots: Node[] = [];
    for (const node of byId.values()) {
      const parent = node.parentId != null ? byId.get(node.parentId) : undefined;
      if (parent) parent.children.push(node);
      else roots.push(node);
    }
    return roots;
  }

  getCategoryById(id: number) {
    return prisma.category.findUnique({
      where: { id },
      include: { _count: { select: { products: true } } },
    });
  }

  async updateCategory(
    id: number,
    data: {
      name?: string;
      description?: string | null;
      imageUrl?: string | null;
      iconName?: string | null;
      sortOrder?: number;
      isActive?: boolean;
      parentId?: number | null;
    },
  ) {
    // Cycle check on re-parent: setting parentId to self or to any of
    // our descendants would orphan the subtree. The startId for the
    // walk is the NEW parent; if that walk ever revisits us, reject.
    if (data.parentId != null) {
      if (data.parentId === id) {
        return { error: 'cycle' as const };
      }
      if (await wouldFormCycle(data.parentId, id)) {
        return { error: 'cycle' as const };
      }
    }

    // Re-slug on rename so customer-facing URLs match the new name.
    let slug: string | undefined;
    if (data.name !== undefined) {
      slug = await uniqueSlug(slugify(data.name), id);
    }

    const updated = await prisma.category.update({
      where: { id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(slug !== undefined && { slug }),
        ...(data.description !== undefined && { description: data.description }),
        ...(data.imageUrl !== undefined && { imageUrl: data.imageUrl }),
        ...(data.iconName !== undefined && { iconName: data.iconName }),
        ...(data.sortOrder !== undefined && { sortOrder: data.sortOrder }),
        ...(data.isActive !== undefined && { isActive: data.isActive }),
        ...(data.parentId !== undefined && { parentId: data.parentId }),
      },
    });
    return { category: updated };
  }

  /// CAT-H2 — the taxonomy is a single GLOBAL table every shop's products
  /// hang off (`Product.categoryId → SetNull`). A hard delete silently nulls
  /// the categoryId of EVERY shop's products in this category and orphans any
  /// child categories — a catalog-wide, cross-tenant mis-categorisation. So we
  /// refuse to delete a category that still has products (in any shop) or child
  /// categories; the admin must re-home or deactivate (`isActive=false`) it
  /// instead. (Write routes are already platform-admin gated in the routes.)
  async deleteCategory(
    id: number,
  ): Promise<
    | { error: 'NOT_FOUND' }
    | { error: 'HAS_PRODUCTS'; products: number }
    | { error: 'HAS_CHILDREN'; children: number }
    | { ok: true }
  > {
    const category = await prisma.category.findUnique({
      where: { id },
      select: { id: true, _count: { select: { products: true, children: true } } },
    });
    if (!category) return { error: 'NOT_FOUND' };
    if (category._count.products > 0) {
      return { error: 'HAS_PRODUCTS', products: category._count.products };
    }
    if (category._count.children > 0) {
      return { error: 'HAS_CHILDREN', children: category._count.children };
    }
    await prisma.category.delete({ where: { id } });
    return { ok: true };
  }
}

export const categoriesService = new CategoriesService();
