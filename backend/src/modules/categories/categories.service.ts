import prisma from '../../infra/db/prisma.js';

export class CategoriesService {
  createCategory(data: {
    name: string;
    description?: string;
    imageUrl?: string;
    iconName?: string;
    sortOrder?: number;
  }) {
    return prisma.category.create({ data });
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
    const where: {
      isActive?: boolean;
      name?: { contains: string; mode: 'insensitive' };
    } = {};
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

  getCategoryById(id: number) {
    return prisma.category.findUnique({
      where: { id },
      include: { _count: { select: { products: true } } },
    });
  }

  updateCategory(
    id: number,
    data: {
      name?: string;
      description?: string | null;
      imageUrl?: string | null;
      iconName?: string | null;
      sortOrder?: number;
      isActive?: boolean;
    }
  ) {
    return prisma.category.update({ where: { id }, data });
  }

  deleteCategory(id: number) {
    return prisma.category.delete({ where: { id } });
  }
}

export const categoriesService = new CategoriesService();
