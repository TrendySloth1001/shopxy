import prisma from '../../infra/db/prisma.js';

export class CategoriesService {
  createCategory(data: {
    name: string;
    description?: string;
    imageUrl?: string;
    sortOrder?: number;
  }) {
    return prisma.category.create({ data });
  }

  async listCategories(options: {
    activeOnly: boolean;
    page: number;
    limit: number;
    skip: number;
  }) {
    const where = options.activeOnly ? { isActive: true } : {};

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
