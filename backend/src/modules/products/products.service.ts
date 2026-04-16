import prisma from '../../infra/db/prisma.js';

export class ProductsService {
  createProduct(data: {
    name: string;
    description?: string;
    sku: string;
    barcode?: string;
    hsnCode?: string;
    imageUrl?: string;
    mrp: number;
    sellingPrice: number;
    purchasePrice: number;
    taxPercent?: number;
    stockQuantity?: number;
    lowStockThreshold?: number;
    unit?: string;
    categoryId?: number;
  }) {
    return prisma.product.create({
      data,
      include: { category: true },
    });
  }

  async listProducts(options: {
    activeOnly: boolean;
    lowStock: boolean;
    categoryId?: number;
    search: string;
    sortBy: string;
    sortOrder: 'asc' | 'desc';
    page: number;
    limit: number;
    skip: number;
  }) {
    const where: Record<string, unknown> = {};

    if (options.activeOnly) where.isActive = true;
    if (options.categoryId) where.categoryId = options.categoryId;
    if (options.search) {
      where.OR = [
        { name: { contains: options.search, mode: 'insensitive' } },
        { sku: { contains: options.search, mode: 'insensitive' } },
        { barcode: { contains: options.search, mode: 'insensitive' } },
      ];
    }
    if (options.lowStock) {
      const lowStockIds = await prisma.$queryRaw<{ id: number }[]>`
        SELECT id FROM products
        WHERE is_active = true AND stock_quantity <= low_stock_threshold
      `;
      where.id = { in: lowStockIds.map((record) => record.id) };
    }

    const [products, total] = await Promise.all([
      prisma.product.findMany({
        where,
        orderBy: { [options.sortBy]: options.sortOrder },
        skip: options.skip,
        take: options.limit,
        include: { category: true },
      }),
      prisma.product.count({ where }),
    ]);

    return { products, total };
  }

  lookupProduct(code: string) {
    return prisma.product.findFirst({
      where: {
        OR: [{ barcode: code }, { sku: code }],
      },
      include: { category: true },
    });
  }

  getProductById(id: number) {
    return prisma.product.findUnique({
      where: { id },
      include: {
        category: true,
        stockTransactions: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
  }

  updateProduct(
    id: number,
    data: {
      name?: string;
      description?: string | null;
      sku?: string;
      barcode?: string | null;
      hsnCode?: string | null;
      imageUrl?: string | null;
      mrp?: number;
      sellingPrice?: number;
      purchasePrice?: number;
      taxPercent?: number;
      lowStockThreshold?: number;
      unit?: string;
      categoryId?: number | null;
      isActive?: boolean;
    }
  ) {
    return prisma.product.update({
      where: { id },
      data,
      include: { category: true },
    });
  }

  deleteProduct(id: number) {
    return prisma.product.delete({ where: { id } });
  }
}

export const productsService = new ProductsService();
